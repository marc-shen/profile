;;; init-python.el --- Python development -*- lexical-binding: t; -*-

(defgroup init-python nil
  "Python development configuration."
  :group 'languages)

(use-package python
  :ensure nil
  ;; `major-mode-remap-alist' promotes these to `python-ts-mode' when its
  ;; grammar is present and leaves them usable as `python-mode' beforehand.
  :mode ("\\.py\\'" . python-mode)
  :interpreter (("python" . python-mode)
                ("python3" . python-mode))
  :custom
  (python-indent-offset 4)
  (python-shell-interpreter "python")
  :bind (:map python-mode-map
              ("C-c C-c" . python-shell-send-buffer)
              ("C-c C-r" . python-shell-send-region)
              ("C-c C-z" . python-shell-switch-to-shell)))

;; Pet resolves the project's virtualenv.  It has to run before `eglot-ensure',
;; otherwise Pyright indexes the global interpreter and cannot complete any
;; third-party import.  The negative depth keeps it ahead of the Eglot hook.
(use-package pet
  :if (package-installed-p 'pet)
  :init
  (add-hook 'python-mode-hook #'pet-mode -10)
  (add-hook 'python-ts-mode-hook #'pet-mode -10))
(use-package reformatter
  :if (package-installed-p 'reformatter)
  :config
  (reformatter-define ruff-format
    :program "ruff" :args '("format" "-") :group 'init-python)
  (reformatter-define black-format
    :program "black" :args '("-") :group 'init-python))
(use-package csv-mode
  :if (package-installed-p 'csv-mode)
  :mode "\\.csv\\'")

(provide 'init-python)

;;; init-python.el ends here
