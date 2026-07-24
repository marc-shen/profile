;;; init-ui.el --- User interface -*- lexical-binding: t; -*-

(dolist (mode '(menu-bar-mode tool-bar-mode scroll-bar-mode))
  (when (fboundp mode)
    (funcall mode -1)))

;; Do not enumerate system fonts during startup; Emacs falls back gracefully.
(set-face-attribute 'default nil :family "MesloLGS NF" :height 120)

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(global-hl-line-mode 1)
(add-hook 'prog-mode-hook
          (lambda () (setq-local show-trailing-whitespace t)))

(setq scroll-conservatively 101
      scroll-margin 3
      mouse-wheel-scroll-amount '(3 ((shift) . 1))
      mouse-wheel-progressive-speed nil)

(use-package which-key
  :if (package-installed-p 'which-key)
  :demand t
  :config (which-key-mode 1)
  :custom (which-key-idle-delay 0.35)
  (which-key-idle-secondary-delay 0.05)
  (which-key-side-window-location 'bottom)
  (which-key-show-remaining-keys t))

(provide 'init-ui)

;;; init-ui.el ends here
