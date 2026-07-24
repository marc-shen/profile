;;; init-development.el --- Development tools -*- lexical-binding: t; -*-

;;; Commentary:
;; Completion, Python, LSP, diagnostics, snippets and Git integration.

;;; Code:


;; ---------------------------------------------------------------------------
;; Completion styles
;; ---------------------------------------------------------------------------

;; Orderless allows completion candidates to be matched using
;; space-separated components in any order.
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles partial-completion)))))


;; ---------------------------------------------------------------------------
;; Minibuffer completion
;; ---------------------------------------------------------------------------

;; Vertical completion interface for commands, files and buffers.
(use-package vertico
  :init
  (vertico-mode 1))

;; Display annotations beside minibuffer completion candidates.
(use-package marginalia
  :init
  (marginalia-mode 1))

;; Enhanced searching and navigation commands.
(use-package consult
  :bind
  (("C-s"     . consult-line)
   ("C-x b"   . consult-buffer)
   ("C-x C-r" . consult-recent-file)
   ("M-g g"   . consult-goto-line)
   ("M-g i"   . consult-imenu)
   ("M-g M-g" . consult-goto-line)
   ("M-y"     . consult-yank-pop)))


;; ---------------------------------------------------------------------------
;; In-buffer completion
;; ---------------------------------------------------------------------------

;; Completion popup shown inside editing buffers.
(use-package corfu
  :init
  (global-corfu-mode 1)

  :custom
  ;; Show completion automatically while typing.
  (corfu-auto t)

  ;; Delay before the popup appears.
  (corfu-auto-delay 0.15)

  ;; Number of characters required before automatic completion.
  (corfu-auto-prefix 2)

  ;; Allow cycling from the last candidate back to the first.
  (corfu-cycle t)

  ;; Show documentation for the selected candidate.
  (corfu-popupinfo-delay '(0.5 . 0.2))

  :bind
  (:map corfu-map
        ("TAB"   . corfu-insert)
        ([tab]   . corfu-insert)
        ("C-n"   . corfu-next)
        ("C-p"   . corfu-previous)
        ("C-g"   . corfu-quit)
        ("M-d"   . corfu-info-documentation)
        ("M-l"   . corfu-info-location))

  :config
  (corfu-popupinfo-mode 1))

;; Extra completion-at-point backends.
(use-package cape
  :init
  ;; Complete file paths.
  (add-to-list 'completion-at-point-functions #'cape-file)

  ;; Complete words found in open buffers.
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))


;; ---------------------------------------------------------------------------
;; Snippets
;; ---------------------------------------------------------------------------

(use-package yasnippet
  :hook
  ((prog-mode . yas-minor-mode))

  :config
  (yas-reload-all))

(use-package yasnippet-snippets
  :after yasnippet)


;; ---------------------------------------------------------------------------
;; Project management
;; ---------------------------------------------------------------------------

;; project.el is included with Emacs.
(use-package project
  :ensure nil
  :bind
  (("C-c p f" . project-find-file)
   ("C-c p b" . project-switch-to-buffer)
   ("C-c p d" . project-dired)
   ("C-c p c" . project-compile)
   ("C-c p p" . project-switch-project)))


;; ---------------------------------------------------------------------------
;; LSP
;; ---------------------------------------------------------------------------

;; Eglot is included with Emacs 29 and later.
(use-package eglot
  :ensure nil

  :commands
  (eglot
   eglot-ensure
   eglot-rename
   eglot-code-actions)

  :hook
  ((python-mode    . eglot-ensure)
   (python-ts-mode . eglot-ensure))

  :bind
  (:map eglot-mode-map
        ("C-c l a" . eglot-code-actions)
        ("C-c l r" . eglot-rename)
        ("C-c l f" . eglot-format-buffer)
        ("C-c l d" . eldoc-doc-buffer)
        ("C-c l q" . eglot-shutdown))

  :custom
  ;; Do not display events buffer unless debugging Eglot.
  (eglot-events-buffer-size 0)

  ;; Shut down a language server after its last managed buffer is closed.
  (eglot-autoshutdown t)

  ;; Keep completion candidates responsive.
  (eglot-send-changes-idle-time 0.2)

  :config
  ;; Use Pyright as the Python language server.
  (add-to-list
   'eglot-server-programs
   '((python-mode python-ts-mode)
     . ("pyright-langserver" "--stdio"))))

;; Search symbols reported by Eglot.
(use-package consult-eglot
  :after (consult eglot)
  :bind
  (:map eglot-mode-map
        ("C-c l s" . consult-eglot-symbols)))


;; ---------------------------------------------------------------------------
;; Diagnostics
;; ---------------------------------------------------------------------------

;; Flymake is included with Emacs and integrates directly with Eglot.
(use-package flymake
  :ensure nil

  :bind
  (:map flymake-mode-map
        ("M-n"     . flymake-goto-next-error)
        ("M-p"     . flymake-goto-prev-error)
        ("C-c ! l" . flymake-show-buffer-diagnostics)
        ("C-c ! p" . flymake-show-project-diagnostics))

  :custom
  ;; Start syntax checking shortly after editing stops.
  (flymake-no-changes-timeout 0.5))


;; ---------------------------------------------------------------------------
;; Python
;; ---------------------------------------------------------------------------

;; python.el is included with Emacs.
(use-package python
  :ensure nil

  :mode
  ("\\.py\\'" . python-mode)

  :interpreter
  ("python3" . python-mode)

  :custom
  (python-indent-offset 4)

  :bind
  (:map python-mode-map
        ("C-c C-c" . python-shell-send-buffer)
        ("C-c C-r" . python-shell-send-region)
        ("C-c C-z" . python-shell-switch-to-shell)))


;; ---------------------------------------------------------------------------
;; Git
;; ---------------------------------------------------------------------------

;; Full Git interface.
(use-package magit
  :commands magit-status

  :bind
  (("C-x g" . magit-status)
   ("C-c g b" . magit-blame-addition))

  :custom
  ;; Reuse the current window when opening Magit.
  (magit-display-buffer-function
   #'magit-display-buffer-same-window-except-diff-v1))

;; Display uncommitted changes in the fringe.
(use-package diff-hl
  :hook
  ((prog-mode       . diff-hl-mode)
   (text-mode       . diff-hl-mode)
   (dired-mode      . diff-hl-dired-mode)
   (magit-post-refresh . diff-hl-magit-post-refresh))

  :config
  ;; Terminal Emacs has no graphical fringe, so use the margin instead.
  (add-hook
   'diff-hl-mode-hook
   (lambda ()
     (unless (display-graphic-p)
       (diff-hl-margin-mode 1)))))


(use-package which-key
  :defer 1

  :config
  (which-key-mode 1)

  :custom
  (which-key-idle-delay 0.3)
  (which-key-idle-secondary-delay 0.05)
  (which-key-max-description-length 40)
  (which-key-max-display-columns 5)
  (which-key-sort-order #'which-key-key-order-alpha)
  (which-key-side-window-location 'bottom)
  (which-key-show-remaining-keys t))

(provide 'init-development)

;;; init-development.el ends here
