;;; init-python.el --- Python development -*- lexical-binding: t; -*-

(use-package python
  :ensure nil
  :mode ("\\.py\\'" . python-mode)
  :interpreter ("python3" . python-mode)
  :hook ((python-mode . (lambda () (init-eglot-ensure-if-available "pyright-langserver")))
         (python-ts-mode . (lambda () (init-eglot-ensure-if-available "pyright-langserver"))))
  :custom
  (python-indent-offset 4)
  (python-shell-interpreter "python")
  :bind (:map python-mode-map
              ("C-c C-c" . python-shell-send-buffer)
              ("C-c C-r" . python-shell-send-region)
              ("C-c C-z" . python-shell-switch-to-shell)))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("pyright-langserver" "--stdio"))))

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
  (reformatter-define ruff-format :program "ruff" :args '("format" "-"))
  (reformatter-define black-format :program "black" :args '("-")))
(use-package csv-mode
  :if (package-installed-p 'csv-mode)
  :mode "\\.csv\\'")

(provide 'init-python)

;;; init-python.el ends here
