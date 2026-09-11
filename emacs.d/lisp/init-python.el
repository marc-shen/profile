;;; init-python.el --- Python development -*- lexical-binding: t; -*-

(defgroup init-python nil
  "Python development configuration."
  :group 'languages)

(defun my-jupytext--run (&rest arguments)
  "Run Jupytext on the current file with ARGUMENTS.

Save the current buffer first, then reload it after a successful conversion so
the text shown by Emacs agrees with the file Jupytext may have updated."
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file"))
  (unless (executable-find "jupytext")
    (user-error
     "Jupytext is not on PATH; install it with `uv tool install jupytext`"))
  (when (buffer-modified-p)
    (save-buffer))
  (let ((output (get-buffer-create "*Jupytext*"))
        (file buffer-file-name))
    (with-current-buffer output
      (erase-buffer))
    (let ((exit-code (apply #'process-file "jupytext" nil output nil
                            (append arguments (list file)))))
      (if (equal exit-code 0)
          (progn
            (revert-buffer :ignore-auto :noconfirm)
            (message "Jupytext updated %s" (file-name-nondirectory file)))
        (display-buffer output)
        (user-error "Jupytext failed with exit code %s" exit-code)))))

(defun my-jupytext-pair-notebook ()
  "Pair the current notebook with a Python percent-format script.

The resulting `.ipynb' keeps outputs while the `.py' file is pleasant to edit
and review.  Run `my-jupytext-sync' after editing either representation."
  (interactive)
  (my-jupytext--run "--set-formats" "ipynb,py:percent"))

(defun my-jupytext-sync ()
  "Synchronize all Jupytext representations paired with the current file."
  (interactive)
  (my-jupytext--run "--sync"))

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

;; A percent-format script remains ordinary Python -- Eglot, formatters and
;; Git all see readable text -- while `code-cells-mode' adds notebook-style
;; navigation and evaluation.  `code-cells-mode-maybe' deliberately leaves
;; normal Python files alone.  Opening an ipynb file directly is also supported
;; through Jupytext, but paired files are preferable because their ipynb side
;; retains rich outputs.
(use-package code-cells
  :if (package-installed-p 'code-cells)
  :commands (code-cells-mode-maybe code-cells-convert-ipynb
             code-cells-write-ipynb)
  :hook ((python-mode . code-cells-mode-maybe)
         (python-ts-mode . code-cells-mode-maybe))
  :bind (:map code-cells-mode-map
              ("C-c C-c" . code-cells-eval)
              ("C-c % j" . my-jupytext-sync)))

(provide 'init-python)

;;; init-python.el ends here
