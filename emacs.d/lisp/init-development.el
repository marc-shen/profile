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
              ("TAB" . corfu-insert) ([tab] . corfu-insert)
              ("C-n" . corfu-next) ("C-p" . corfu-previous)
              ("C-g" . corfu-quit) ("M-d" . corfu-info-documentation))
  :config (corfu-popupinfo-mode 1))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-keyword)
  :custom
  (cape-dabbrev-check-other-buffers nil))

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

(use-package yasnippet
  :defer 1
  :config (yas-global-mode 1))
(use-package yasnippet-snippets :after yasnippet)

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

(provide 'init-development)

;;; init-development.el ends here
