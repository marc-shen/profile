;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-

(setq package-enable-at-startup nil
      gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6
      frame-inhibit-implied-resize t)

;; Use English for Emacs packages and every subprocess it starts (including
;; Git), while leaving UTF-8 file handling configured in `init-base'.
(set-language-environment "English")
(setenv "LANGUAGE" "en")
(setenv "LC_ALL" "C")
(setenv "LC_MESSAGES" "C")

;; File-name handlers are mainly for remote files and slow down startup.
(defvar my-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist my-file-name-handler-alist)))

(dolist (mode '(menu-bar-mode tool-bar-mode scroll-bar-mode))
  (when (fboundp mode)
    (funcall mode -1)))

(setq initial-frame-alist '((fullscreen . maximized)))
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(provide 'early-init)

;;; early-init.el ends here
