;;; init-latex.el --- LaTeX writing environment -*- lexical-binding: t; -*-

(use-package tex
  :if (package-installed-p 'auctex)
  :defer t
  :mode ("\\.tex\\'" . LaTeX-mode)
  :hook ((LaTeX-mode . visual-line-mode)
         (LaTeX-mode . flyspell-mode)
         (LaTeX-mode . LaTeX-math-mode)
         (LaTeX-mode . turn-on-reftex))
  :custom
  (TeX-auto-save t)
  (TeX-parse-self t)
  (TeX-save-query nil)
  (TeX-command-default "LaTeXMk")
  (TeX-source-correlate-mode t)
  (TeX-source-correlate-start-server t)
  (TeX-electric-sub-and-superscript t)
  (LaTeX-electric-left-right-brace t)
  (reftex-plug-into-AUCTeX t)
  :config
  ;; Recent AUCTeX versions provide LaTeXMk.  Keep a compatible fallback for
  ;; older versions without adding a second, differently-cased menu entry.
  (unless (assoc "LaTeXMk" TeX-command-list)
    (add-to-list 'TeX-command-list
                 '("LaTeXMk"
                   "latexmk -pdf -interaction=nonstopmode -synctex=1 %s"
                   TeX-run-TeX nil t
                   :help "Run LaTeXMk"))))

;; Fedora's hunspell-en package exposes regional dictionaries such as en_US,
;; not the generic `en' name inferred from some locales.
(setq ispell-program-name "hunspell"
      ispell-dictionary "en_US")

(use-package pdf-tools
  :if (package-installed-p 'pdf-tools)
  :defer t
  :mode ("\\.pdf\\'" . pdf-view-mode))
(use-package citar
  :if (package-installed-p 'citar)
  :defer t
  :bind (:map LaTeX-mode-map ("C-c ]" . citar-insert-citation)))
(use-package writegood-mode
  :if (package-installed-p 'writegood-mode)
  :defer t
  :hook ((LaTeX-mode . writegood-mode) (org-mode . writegood-mode)))

(provide 'init-latex)

;;; init-latex.el ends here
