;;; init-completion.el --- Completion framework -*- lexical-binding: t; -*-

(use-package vertico
  :demand t
  :init (vertico-mode 1)
  ;; Keys stay at their Vertico defaults here: TAB accepts the selection
  ;; (`vertico-insert'), C-n/C-p move through candidates.  Only the Corfu popup
  ;; cycles with TAB / S-TAB.
  :custom (vertico-cycle t) (vertico-count 12))

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
         ;; fd replaces find: it walks the tree in parallel, skips whatever
         ;; .gitignore lists, and matches case-insensitively unless the pattern
         ;; itself is capitalized.  Together with the `~' flex dispatcher this
         ;; covers what fzf is normally reached for.
         ;;
         ;; Bound to `M-s d', not the more obvious `M-s f': Dired makes the
         ;; latter a prefix of its own (`M-s f C-s' searches file names only),
         ;; and a local map wins, so the binding would silently die in exactly
         ;; the buffers where searching a directory tree is most useful.
         ("M-s d" . consult-fd) ("C-c m" . consult-mode-command))
  ;; Dotfiles are the point of this repository, so do not let fd hide them; .git
  ;; itself only adds thousands of uninteresting object paths.
  :custom (consult-fd-args
           '((if (executable-find "fdfind" 'remote) "fdfind" "fd")
             "--full-path --hidden --exclude .git --color=never")))

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
