;;; init.el --- Main Emacs configuration -*- lexical-binding: t; -*-

;; Keep this configuration relocatable when it is loaded with `emacs -l'.
(defconst my-config-directory
  (file-name-directory (file-truename (or load-file-name buffer-file-name))))
(setq user-emacs-directory my-config-directory)

(add-to-list 'load-path (expand-file-name "lisp" my-config-directory))

(setq custom-file (expand-file-name "custom.el" my-config-directory))
(load custom-file 'noerror 'nomessage)

(require 'init-package)
(require 'init-base)
(require 'init-ui)
(require 'init-theme)
(require 'init-keymap)
(require 'init-completion)
(require 'init-project)
(require 'init-development)
(require 'init-python)
(require 'init-c)
(require 'init-fortran)
(require 'init-latex)
(require 'init-org)
(require 'init-git)

;; Restore normal garbage-collection settings after startup.
(setq gc-cons-threshold (* 64 1024 1024)
      gc-cons-percentage 0.1)

(provide 'init)

;;; init.el ends here
