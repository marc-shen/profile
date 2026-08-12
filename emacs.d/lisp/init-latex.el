;;; init-latex.el --- LaTeX writing environment -*- lexical-binding: t; -*-

;; Pick whichever spell checker the machine has: the Linux box uses hunspell
;; (Fedora's hunspell-en exposes regional dictionaries such as en_US, not the
;; generic `en' name some locales infer), this Mac has aspell.  Naming a
;; program that is not installed makes flyspell fail in every LaTeX buffer.
(cond ((executable-find "hunspell")
       (setq ispell-program-name "hunspell"
             ispell-dictionary "en_US"))
      ((executable-find "aspell")
       (setq ispell-program-name "aspell"
             ispell-dictionary "en_US")))

(defun init-latex-flyspell-if-available ()
  "Enable `flyspell-mode' only when a spell checker is installed.
Mirrors `my-eglot-ensure-if-available': an optional external tool should
leave the mode it supports unavailable, not signal on every file visit."
  (when (executable-find ispell-program-name)
    (flyspell-mode 1)))

(use-package tex
  :if (package-installed-p 'auctex)
  :defer t
  :mode ("\\.tex\\'" . LaTeX-mode)
  :hook ((LaTeX-mode . visual-line-mode)
         (LaTeX-mode . init-latex-flyspell-if-available)
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

(use-package citar
  :if (package-installed-p 'citar)
  :commands citar-insert-citation
  :init
  ;; AUCTeX defines `LaTeX-mode-map' in latex.el, so install the binding only
  ;; after that feature has created the map.
  (with-eval-after-load 'latex
    (keymap-set LaTeX-mode-map "C-c ]" #'citar-insert-citation)))
(use-package writegood-mode
  :if (package-installed-p 'writegood-mode)
  :defer t
  :hook ((LaTeX-mode . writegood-mode) (org-mode . writegood-mode)))

(provide 'init-latex)

;;; init-latex.el ends here
