;;; init-development.el --- General development tools -*- lexical-binding: t; -*-

;; Language servers, snippets, diagnostics, and the editing helpers that are
;; useful in any programming buffer.  Completion itself lives in
;; `init-completion', which is loaded first.

;; Yasnippet must be loaded before Eglot connects: `eglot--snippet-expansion-fn'
;; tests for `yas-minor-mode' to decide whether to advertise snippetSupport, and
;; without it servers send plain labels instead of parameter placeholders.
(use-package yasnippet
  :demand t
  :config (yas-global-mode 1))
(use-package yasnippet-snippets :after yasnippet)

(use-package eglot
  :ensure nil
  :commands (eglot eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-confirm-server-initiated-edits nil)
  (eglot-events-buffer-size 0)
  (eglot-send-changes-idle-time 0.2)
  :bind (:map eglot-mode-map
              ("C-c l a" . eglot-code-actions)
              ("C-c l r" . eglot-rename)
              ("C-c l f" . eglot-format-buffer)
              ("C-c l d" . eldoc-doc-buffer)
              ("C-c l q" . eglot-shutdown)))

;; Eglot's capf declares itself exclusive, which suppresses the Cape backends
;; whenever a server replies.  Making it non-exclusive lets keyword and dabbrev
;; completion fill the gaps the server leaves.
(with-eval-after-load 'eglot
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (when (require 'cape nil t)
                (setq-local completion-at-point-functions
                            (cons (cape-capf-nonexclusive #'eglot-completion-at-point)
                                  (remq #'eglot-completion-at-point
                                        completion-at-point-functions)))))))

;; Avoid startup errors when an optional language server is not installed.
(defun init-eglot-ensure-if-available (program)
  "Start Eglot only when PROGRAM is available on PATH."
  (when (executable-find program)
    (eglot-ensure)))

(use-package consult-eglot
  :after (consult eglot)
  :bind (:map eglot-mode-map ("C-c l s" . consult-eglot-symbols)))

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)
              ("C-c ! p" . flymake-show-project-diagnostics))
  :custom (flymake-no-changes-timeout 0.5))

(use-package compile
  :ensure nil
  :custom
  (compilation-scroll-output 'first-error)
  (compilation-always-kill t)
  (compilation-ask-about-save nil))
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

(use-package helpful
  :if (package-installed-p 'helpful)
  :bind (([remap describe-function] . helpful-callable)
         ([remap describe-command] . helpful-command)
         ([remap describe-variable] . helpful-variable)
         ([remap describe-key] . helpful-key)))
(use-package rainbow-delimiters
  :if (package-installed-p 'rainbow-delimiters)
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package hl-todo
  :if (package-installed-p 'hl-todo)
  :hook (prog-mode . hl-todo-mode))

(use-package multiple-cursors
  :if (package-installed-p 'multiple-cursors)
  :custom
  ;; Per-command "run once or for every cursor" answers are local state.
  (mc/list-file (expand-file-name "mc-lists.el" init-var-directory))
  :bind (("C-c e l" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c e a" . mc/mark-all-like-this)
         ("C-c e r" . mc/mark-all-in-region)
         ("C-c e n" . mc/skip-to-next-like-this)
         ("C-c e p" . mc/skip-to-previous-like-this)
         ("C-c e u" . mc/unmark-next-like-this)
         ("C-c e SPC" . mc/vertical-align-with-space))
  :config
  ;; Corfu's popup only tracks the real cursor, and auto-completion fires on
  ;; every fake one.  Suspend it while several cursors are live.
  (add-hook 'multiple-cursors-mode-enabled-hook
            (lambda ()
              (setq-local corfu-auto nil)
              (when (fboundp 'corfu-quit) (corfu-quit))))
  (add-hook 'multiple-cursors-mode-disabled-hook
            (lambda () (kill-local-variable 'corfu-auto))))

(provide 'init-development)

;;; init-development.el ends here
