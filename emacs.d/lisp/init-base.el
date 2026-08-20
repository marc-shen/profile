;;; init-base.el --- Basic editing behavior -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-buffer-choice nil
      initial-scratch-message nil)

;; Let `emacsclient' reuse this Emacs instance.  `server-start' is idempotent
;; here, so evaluating the configuration again does not create another server.
(require 'server)
(unless (server-running-p)
  (server-start))

;; uv installs user-wide tools here on both macOS and Linux.  GUI Emacs may
;; not inherit the shell's updated PATH, so keep `exec-path' in sync explicitly.
(let ((user-bin-directory (expand-file-name "~/.local/bin")))
  (add-to-list 'exec-path user-bin-directory)
  (unless (member user-bin-directory
                  (split-string (or (getenv "PATH") "") path-separator t))
    (setenv "PATH"
            (concat user-bin-directory path-separator (or (getenv "PATH") "")))))

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

(provide 'init-base)

;;; init-base.el ends here
