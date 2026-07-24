;;; init-custom.el --- User interface -*- lexical-binding: t; -*-

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(column-number-mode 1)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)

(setq display-line-numbers-type 'relative)

(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-buffer-choice nil
      initial-scratch-message nil)

(set-face-attribute 'default nil
                    :family "MesloLGS NF"
                    :height 120)

;; Do not create backup files (file~)
(setq make-backup-files nil)

;; Do not create auto-save files (#file#)
(setq auto-save-default nil)

;; Do not create lock files (.#file)
(setq create-lockfiles nil)

(setq intial-frame-alist
      '((fullscreen . maximized)))
(add-hook 'window-setup-hook
	  #'toggle-frame-maximized)

(windmove-default-keybindings)

(provide 'init-custom)
