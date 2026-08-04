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
(defconst my-var-directory (expand-file-name "var/" user-emacs-directory))
(make-directory my-var-directory t)
(setq backup-directory-alist `(("." . ,(expand-file-name "backups/" my-var-directory)))
      auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" my-var-directory) t))
      auto-save-list-file-prefix (expand-file-name "auto-save/.saves-" my-var-directory)
      savehist-file (expand-file-name "history" my-var-directory)
      save-place-file (expand-file-name "places" my-var-directory)
      recentf-save-file (expand-file-name "recentf" my-var-directory)
      create-lockfiles t)
(make-directory (expand-file-name "backups/" my-var-directory) t)
(make-directory (expand-file-name "auto-save/" my-var-directory) t)

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

(provide 'init-base)

;;; init-base.el ends here
