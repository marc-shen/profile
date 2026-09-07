;;; init-markdown.el --- Markdown writing environment -*- lexical-binding: t; -*-

;; Emacs 31 supplies the Tree-sitter major mode.  It understands CommonMark
;; and the GFM extensions used by README files, so one mode now covers every
;; Markdown extension instead of splitting files between markdown-mode and
;; gfm-mode.  Its two pinned grammar recipes are declared by the library itself;
;; `my-install-packages' installs them along with the external packages.
(require 'init-latex)

(declare-function visual-fill-column-adjust "visual-fill-column")

(use-package markdown-ts-mode
  :ensure nil
  :defer t
  :mode "\\.\\(?:md\\|markdown\\|mkd\\|mdown\\|mkdn\\|mdwn\\|mdx\\)\\'"
  :hook ((markdown-ts-mode . visual-line-mode)
         (markdown-ts-mode . init-latex-flyspell-if-available))
  :custom
  ;; Hide syntax by default; markdown-ts-appear reveals the smallest element at
  ;; point, so the source remains directly editable without a separate preview
  ;; state.
  (markdown-ts-hide-markup t)
  (markdown-ts-inline-images t)
  (markdown-ts-image-max-width 'window)
  (markdown-ts-display-remote-inline-images nil)
  (markdown-ts-fontify-code-blocks-natively t)
  (markdown-ts-enable-code-block-context-mode t)
  (markdown-ts-enable-table-mode t)
  (markdown-ts-table-auto-align '(cell-navigation transpose))
  :config
  ;; Fence names that do not map cleanly to an Emacs major-mode name.
  (dolist (entry '((console sh-mode)
                   (shell-session sh-mode)
                   (zsh bash-ts-mode)))
    (add-to-list 'markdown-ts-code-block-modes entry)))

(use-package markdown-ts-appear
  :if (package-installed-p 'markdown-ts-appear)
  :after markdown-ts-mode
  :hook (markdown-ts-mode . markdown-ts-appear-mode)
  :custom
  ;; This configuration uses Helix rather than Evil or Meow.  The generic
  ;; trigger follows point in every modal state and therefore works in both
  ;; insert and normal state.
  (markdown-ts-appear-trigger 'always)
  (markdown-ts-appear-enable-math-preview t)
  (markdown-ts-appear-math-scale 1.1)
  (markdown-ts-appear-link-icon '("" . "↗"))
  (markdown-ts-appear-image-icon '("" . "▧"))
  (markdown-ts-appear-code-fence-style 'connected)
  (markdown-ts-appear-label-caps '("" . ""))
  (markdown-ts-appear-render-callouts t)
  (markdown-ts-appear-block-quote-marker "▎")
  (markdown-ts-appear-table-style 'unicode))

(use-package visual-fill-column
  :if (package-installed-p 'visual-fill-column)
  :hook (markdown-ts-mode . visual-fill-column-mode)
  :config
  ;; Recenter immediately after `C-x f' changes this buffer's writing width.
  (advice-add 'set-fill-column :after #'visual-fill-column-adjust))

(provide 'init-markdown)

;;; init-markdown.el ends here
