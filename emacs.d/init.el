;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

;; Load system settings from a separate file.
(setq custom-file
      (expand-file-name "custom.el" user-emacs-directory))
(load custom-file 'noerror 'nomessage)

;; Add ~/.emacs.d/lisp to load-path.
(add-to-list 'load-path
             (expand-file-name "lisp" user-emacs-directory))

;; Load configuration modules.
(require 'init-package)
(require 'init-custom)
(require 'init-theme)
(require 'init-development)
(provide 'init)

