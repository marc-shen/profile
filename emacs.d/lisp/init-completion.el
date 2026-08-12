;;; init-completion.el --- Completion frameworks -*- lexical-binding: t; -*-

;; Two separate stacks: Vertico and friends complete in the minibuffer, Corfu
;; and Cape complete in the buffer.  They share `completion-styles', so they
;; are configured together even though neither depends on the other.


;;; Minibuffer completion.

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


;;; In-buffer completion.

(use-package corfu
  :demand t
  :init (global-corfu-mode 1)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  (corfu-quit-no-match 'separator)
  (corfu-popupinfo-delay '(0.5 . 0.2))
  :bind (:map corfu-map
              ;; TAB / S-TAB cycle the candidates, RET inserts the selection.
              ("TAB" . corfu-next) ([tab] . corfu-next)
              ("S-TAB" . corfu-previous) ([backtab] . corfu-previous)
              ("RET" . corfu-insert) ([return] . corfu-insert)
              ("M-TAB" . corfu-expand)
              ("C-g" . corfu-quit) ("M-d" . corfu-info-documentation))
  :config
  (corfu-popupinfo-mode 1)
  ;; Corfu grabs C-n/C-p through `next-line'/`previous-line' remappings.  Undo
  ;; them so those keys always move point; the popup then closes on its own,
  ;; since neither command matches `corfu-continue-commands'.
  (define-key corfu-map [remap next-line] nil)
  (define-key corfu-map [remap previous-line] nil))

(use-package cape
  :init
  ;; Use `add-hook' rather than `add-to-list': init.el is loaded inside
  ;; *scratch*, where `completion-at-point-functions' is buffer-local, so
  ;; `add-to-list' would register these backends in that buffer alone.
  (add-hook 'completion-at-point-functions #'cape-file 10)
  (add-hook 'completion-at-point-functions #'cape-keyword 20)
  (add-hook 'completion-at-point-functions #'cape-dabbrev 30)
  :custom
  ;; Scan buffers sharing the current major mode: broad enough to be useful in
  ;; a multi-file project, narrow enough to keep the candidate list relevant.
  ;; (The old `cape-dabbrev-check-other-buffers' no longer exists in Cape.)
  (cape-dabbrev-buffer-function #'cape-same-mode-buffers))

;; Emacs Lisp buffers set `completion-at-point-functions' locally without the
;; `t' marker, so the global Cape backends never run there.  Rebuild the list.
(add-hook 'emacs-lisp-mode-hook
          (lambda ()
            (setq-local completion-at-point-functions
                        (list #'elisp-completion-at-point #'cape-file
                              #'cape-dabbrev))))

(provide 'init-completion)

;;; init-completion.el ends here
