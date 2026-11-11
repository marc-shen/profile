;;; init-latex.el --- LaTeX writing environment -*- lexical-binding: t; -*-

(defvar LaTeX-mode-map)
(defvar TeX-command-default)
(defvar TeX-command-next)
(defvar TeX-command-Show)
(defvar TeX-command-buffer)
(defvar TeX-sentinel-function)
(defvar TeX-sentinel-default-function)
(defvar ispell-dictionary)
(defvar ispell-program-name)

(defun init-latex-use-latexmk ()
  "Use latexmk after AUCTeX initializes its buffer-local command default."
  (setq-local TeX-command-default "LaTeXMk"))

(defun init-latex-latexmk-sentinel (process name)
  "Use latexmk's final exit status, not intermediate LaTeX warnings."
  (if (and (eq (process-status process) 'exit)
           (zerop (process-exit-status process)))
      (let ((output (with-current-buffer TeX-command-buffer
                      (TeX-active-master (TeX-output-extension)))))
        (if (file-readable-p output)
            (progn
              (setq TeX-command-next TeX-command-Show)
              (run-hook-with-args 'TeX-after-compilation-finished-functions
                                  output)
              (message "%s: finished; output is up to date" name))
          (setq TeX-command-next TeX-command-default)
          (message "%s: output missing: %s" name output)))
    ;; Preserve AUCTeX's normal error reporting when latexmk fails.
    (TeX-LaTeX-sentinel process name)))

(defun init-latex-run-latexmk (name command file)
  "Run latexmk with a sentinel that understands its multi-pass output."
  (let ((TeX-sentinel-default-function #'init-latex-latexmk-sentinel))
    (TeX-run-TeX name command file)))

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
Mirrors `init-eglot-ensure-if-available': an optional external tool should
leave the mode it supports unavailable, not signal on every file visit."
  (when (executable-find ispell-program-name)
    (flyspell-mode 1)))

(use-package tex
  :if (package-installed-p 'auctex)
  :defer t
  :mode ("\\.tex\\'" . LaTeX-mode)
  :hook ((LaTeX-mode . visual-line-mode)
         (LaTeX-mode . init-latex-use-latexmk)
         (LaTeX-mode . init-latex-flyspell-if-available)
         (LaTeX-mode . LaTeX-math-mode)
         (LaTeX-mode . turn-on-reftex))
  :custom
  (TeX-auto-save t)
  (TeX-parse-self t)
  (TeX-save-query nil)
  ;; A new run supersedes the one still going, so asking whether to abort it
  ;; has only one answer -- the same reasoning as `compilation-always-kill' in
  ;; `init-development'.
  (TeX-kill-process-without-query t)
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
                   :help "Run LaTeXMk")))
  (setf (nth 2 (assoc "LaTeXMk" TeX-command-list))
        #'init-latex-run-latexmk))

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
  :hook ((LaTeX-mode . writegood-mode) (org-mode . writegood-mode)
         (markdown-ts-mode . writegood-mode)))

(provide 'init-latex)

;;; init-latex.el ends here
