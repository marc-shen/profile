;;; init-development.el --- General development tools -*- lexical-binding: t; -*-

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

;; Emacs Lisp buffers set `completion-at-point-functions' locally without the
;; `t' marker, so the global Cape backends never run there.  Rebuild the list.
(add-hook 'emacs-lisp-mode-hook
          (lambda ()
            (setq-local completion-at-point-functions
                        (list #'elisp-completion-at-point #'cape-file
                              #'cape-dabbrev))))

;; Avoid startup errors when an optional language server is not installed.
(defun my-eglot-ensure-if-available (program)
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
  (mc/list-file (expand-file-name "mc-lists.el" my-var-directory))
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
