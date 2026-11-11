;;; init-theme.el --- Theme configuration -*- lexical-binding: t; -*-

(use-package doom-themes
  :demand t

  :init
  ;; These options must be set before loading the theme.
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)

  :config
  ;; Disable any previously loaded theme.
  (mapc #'disable-theme custom-enabled-themes)

  (load-theme 'doom-monokai-classic t)

  ;; Configure Org only after Org itself is requested.
  (with-eval-after-load 'org
    (doom-themes-org-config))
  (doom-themes-visual-bell-config)
  (set-face-attribute 'line-number-current-line nil :foreground "#ffffff" :weight 'bold)
  (set-face-attribute 'mode-line nil :box nil)
  (set-face-attribute 'mode-line-inactive nil :box nil))

(provide 'init-theme)

;;; init-theme.el ends here
