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

  ;; Load Monokai Classic.
  (load-theme 'doom-monokai-pro t)

  ;; Optional Doom theme integrations.
  (doom-themes-org-config)
  (doom-themes-visual-bell-config))

(provide 'init-theme)

;;; init-theme.el ends here
