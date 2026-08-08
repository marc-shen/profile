;;; init-completion.el --- Completion framework -*- lexical-binding: t; -*-

(use-package vertico
  :demand t
  :init (vertico-mode 1)
  :custom (vertico-cycle t) (vertico-count 12)
  ;; Same TAB / S-TAB cycling as in the Corfu popup.  C-n/C-p keep selecting
  ;; candidates here, which is their only useful meaning in a one-line prompt.
  ;; `vertico-insert' (completing a directory component while finding a file)
  ;; moves to M-TAB.
  :bind (:map vertico-map
              ("TAB" . vertico-next) ([tab] . vertico-next)
              ("S-TAB" . vertico-previous) ([backtab] . vertico-previous)
              ("M-TAB" . vertico-insert)))

(use-package orderless
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  ;; Eglot narrows candidates server-side; without an explicit entry the
  ;; `eglot-capf' category falls back to plain prefix matching in the popup.
  (completion-category-overrides
   '((file (styles partial-completion basic))
     (eglot (styles orderless basic))
     (eglot-capf (styles orderless basic)))))

(use-package marginalia
  :demand t
  :init (marginalia-mode 1))

(use-package consult
  :bind (("C-s" . consult-line) ("C-x b" . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window) ("C-x C-r" . consult-recent-file)
         ("M-y" . consult-yank-pop) ("M-g g" . consult-goto-line)
         ("M-g i" . consult-imenu) ("M-s r" . consult-ripgrep)
         ("M-s f" . consult-find) ("C-c m" . consult-mode-command)))

(use-package embark
  :if (package-installed-p 'embark)
  :bind (("C-." . embark-act) ("C-;" . embark-dwim) ("C-h B" . embark-bindings))
  :init (setq prefix-help-command #'embark-prefix-help-command))
(use-package embark-consult
  :if (and (package-installed-p 'embark)
           (package-installed-p 'embark-consult))
  :after (embark consult))

(provide 'init-completion)

;;; init-completion.el ends here
