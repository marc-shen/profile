;;; init-base.el --- Basic editing behavior -*- lexical-binding: t; -*-

(require 'seq)

(defvar auto-revert-verbose)
(defvar global-auto-revert-non-file-buffers)
(defvar recentf-auto-cleanup)
(defvar recentf-max-saved-items)
(defvar recentf-save-file)
(defvar savehist-file)
(defvar save-place-file)

(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-buffer-choice nil
      initial-scratch-message nil)

;; Let `emacsclient' reuse an ordinary GUI instance too.  Daemon startup calls
;; `server-start' after init has finished; doing it here as well would make the
;; daemon unnecessarily stop and restart its socket during initialization.
(require 'server)
(unless (or (daemonp) (server-running-p))
  (server-start))

;; GUI and daemon Emacs processes do not necessarily inherit the interactive
;; shell's PATH.  Keep both process lookup mechanisms in sync for user tools.
(defun init-base--prepend-executable-directory (directory)
  "Prepend an existing DIRECTORY to `exec-path' and PATH."
  (when (file-directory-p directory)
    (add-to-list 'exec-path directory)
    (unless (member directory
                    (split-string (or (getenv "PATH") "") path-separator t))
      (setenv "PATH"
              (concat directory path-separator (or (getenv "PATH") ""))))))

;; uv and similar tools install user-wide commands here on macOS and Linux.
(init-base--prepend-executable-directory
 (expand-file-name "~/.local/bin"))

;; NVM modifies PATH from interactive shell startup files, which a GUI Emacs
;; never reads.  Prefer the newest installed Node version; normally this is the
;; same version selected by NVM's default alias and keeps MathJax, LSP servers,
;; and other Node-based tools available to Emacs subprocesses.
(let ((versions-directory (expand-file-name "~/.nvm/versions/node")))
  (when (file-directory-p versions-directory)
    (when-let* ((versions
                 (seq-filter
                  #'file-directory-p
                  (directory-files versions-directory t "\\`v[0-9]" t)))
                (newest (car (last (sort versions #'version<)))))
      (init-base--prepend-executable-directory
       (expand-file-name "bin" newest)))))

;; Keep recovery data out of project directories instead of disabling it.
(defconst init-var-directory (expand-file-name "var/" user-emacs-directory))
(make-directory init-var-directory t)
(setq backup-directory-alist `(("." . ,(expand-file-name "backups/" init-var-directory)))
      auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" init-var-directory) t))
      auto-save-list-file-prefix (expand-file-name "auto-save/.saves-" init-var-directory)
      savehist-file (expand-file-name "history" init-var-directory)
      save-place-file (expand-file-name "places" init-var-directory)
      recentf-save-file (expand-file-name "recentf" init-var-directory)
      create-lockfiles t)
(make-directory (expand-file-name "backups/" init-var-directory) t)
(make-directory (expand-file-name "auto-save/" init-var-directory) t)

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8-unix)
(set-default-coding-systems 'utf-8-unix)

(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)
(save-place-mode 1)
(require 'savehist)
(defvar init-python-project-environments nil
  "Project-specific Python environments persisted by `init-python'.")
(add-to-list 'savehist-additional-variables
             'init-python-project-environments)
(savehist-mode 1)
(setq history-length 200)
(setq recentf-max-saved-items 300
      recentf-auto-cleanup 'never)
;; Loading a large recent-files list is not needed before the first command.
(run-with-idle-timer 0.8 nil #'recentf-mode)

(delete-selection-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
(setq show-paren-delay 0
      sentence-end-double-space nil
      require-final-newline t
      use-short-answers t
      enable-recursive-minibuffers t)
(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 88)
(global-so-long-mode 1)
(minibuffer-depth-indicate-mode 1)

;; `*scratch*' is the one buffer that is always safe to type in, but reaching it
;; costs a buffer switch and it is gone for good once killed.  `my-scratch-buffer'
;; recreates it when needed and toggles back to the buffer it came from on a
;; second press, so the same key both goes there and comes back.
(defvar my-scratch--origin nil
  "Buffer `my-scratch-buffer' last jumped to `*scratch*' from.")

(defun my-scratch-buffer (&optional arg)
  "Switch to `*scratch*', creating it if it was killed.
Pressing the same key again from inside `*scratch*' returns to the buffer it
was invoked from.  With a prefix ARG, show `*scratch*' in another window and
leave the current window alone."
  (interactive "P")
  (if (and (not arg) (string= (buffer-name) "*scratch*"))
      ;; Going back through `switch-to-prev-buffer' would land on whatever this
      ;; window happened to show before, which right after startup is a log
      ;; buffer such as *Async-native-compile-log*.  The buffer the jump
      ;; actually started from is remembered instead.
      (if (buffer-live-p my-scratch--origin)
          (switch-to-buffer my-scratch--origin)
        (user-error "No buffer to return to from *scratch*"))
    (unless (string= (buffer-name) "*scratch*")
      (setq my-scratch--origin (current-buffer)))
    (let ((buffer (get-buffer-create "*scratch*")))
      (with-current-buffer buffer
        (unless (derived-mode-p initial-major-mode)
          (funcall initial-major-mode)))
      (if arg
          (switch-to-buffer-other-window buffer)
        (switch-to-buffer buffer)))))

;; `C-x k' kills one buffer at a time, which is the wrong tool after a long
;; session has left dozens of files open.  Killing everything is not right
;; either: `*scratch*', `*Messages*' and the various log and REPL buffers are
;; the ones worth keeping.  The split falls neatly along the `*' convention --
;; buffers whose name starts with `*' (or with a space, which marks Emacs's own
;; internal buffers) are the system's, the rest are the files being worked on.
(defun my-kill-all-user-buffers ()
  "Kill every user buffer, keeping the system buffers.
A buffer counts as the system's when its name starts with `*' or a space, so
`*scratch*', `*Messages*' and friends survive.  Buffers visiting a file with
unsaved changes ask before they go."
  (interactive)
  (let ((killed 0))
    (dolist (buffer (buffer-list))
      (let ((name (buffer-name buffer)))
        (when (and name
                   (not (string-prefix-p "*" name))
                   (not (string-prefix-p " " name))
                   (kill-buffer buffer))
          (setq killed (1+ killed)))))
    (message "Killed %d user buffer%s" killed (if (= killed 1) "" "s"))))

(provide 'init-base)

;;; init-base.el ends here
