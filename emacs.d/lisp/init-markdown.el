;;; init-markdown.el --- Markdown writing environment -*- lexical-binding: t; -*-

;; A Markdown buffer opens in its editing state: markup and formulas are the
;; source text, fontified.  `my-markdown-preview-mode' (C-c C-v) turns that into
;; the reading state, where formulas are images and the characters that only
;; mark up text are hidden.
;;
;; Prose behaves as it does in the other markup languages here, so this borrows
;; what `init-latex' arranged: soft-wrapped lines and whichever spell checker the
;; machine has.  The require only makes that dependency visible -- `init-latex'
;; is loaded unconditionally anyway -- but it is what `ispell-program-name' and
;; `init-latex-flyspell-if-available' come from.
(require 'init-latex)


;;; Editing.

;; The export and preview commands shell out to `markdown-command', whose
;; default is a program literally called `markdown' that is rarely installed.
;; Pick whichever converter this machine has, as the spell checker is picked in
;; `init-latex'.  With none of them only those commands are affected, and they
;; report the missing program themselves.
(cond ((executable-find "pandoc")
       (setq markdown-command
             '("pandoc" "--from=gfm" "--to=html5" "--standalone")))
      ((executable-find "multimarkdown")
       (setq markdown-command "multimarkdown"))
      ((executable-find "cmark-gfm")
       (setq markdown-command "cmark-gfm"))
      ((executable-find "cmark")
       (setq markdown-command "cmark")))

(defun init-markdown-display-images-if-possible ()
  "Show the inline images of the current buffer when Emacs can display them.

`markdown-display-inline-images' signals \"Cannot show images\" when
`display-images-p' is nil -- a terminal frame, or a build without image
support -- which from a mode hook would abort every visit to a Markdown
file.  Only local files are read: `markdown-display-remote-images' is left
off, so opening a file cannot turn into network access."
  (when (display-images-p)
    (markdown-display-inline-images)))

(use-package markdown-mode
  :if (package-installed-p 'markdown-mode)
  :defer t

  ;; The package's own autoload already claims .md, .markdown, .mkd, .mdown,
  ;; .mkdn, .mdwn and .mdx.  The files GitHub renders get its dialect on top --
  ;; task lists, strikethrough, language-tagged fences -- and `M-x gfm-mode'
  ;; switches any other buffer over.  `gfm-mode' derives from `markdown-mode',
  ;; so everything below applies to it too.
  :mode (("README\\.md\\'" . gfm-mode)
         ("CONTRIBUTING\\.md\\'" . gfm-mode)
         ("CHANGELOG\\.md\\'" . gfm-mode))

  :hook ((markdown-mode . visual-line-mode)
         (markdown-mode . init-latex-flyspell-if-available)
         (markdown-mode . init-markdown-display-images-if-possible))

  :custom
  ;; Fenced code is fontified by the language's own major mode, and markdown 2.8
  ;; prefers a tree-sitter mode wherever the grammar is installed.
  (markdown-fontify-code-blocks-natively t)
  (markdown-enable-math t)                ; $...$, as in the LaTeX buffers
  (markdown-enable-highlighting-syntax t) ; ==highlighted==
  (markdown-header-scaling t)
  (markdown-unordered-list-item-prefix "- ")
  (markdown-indent-on-enter 'indent-and-new-item) ; RET continues a list
  ;; `imenu', and therefore `M-g i', follows the heading tree instead of
  ;; listing every heading in the file at one level.
  (markdown-nested-imenu-heading-index t)
  ;; A screenshot is usually wider than the window; cap it rather than scroll
  ;; horizontally past one image.
  (markdown-max-image-size '(1024 . 1024))

  :config
  ;; Emacs has a mode for these, but not under the name the fence uses.
  (dolist (entry '(("json" . js-json-mode)
                   ("toml" . conf-toml-mode)
                   ("console" . sh-mode)
                   ("shell-session" . sh-mode)
                   ("zsh" . sh-mode)))
    (add-to-list 'markdown-code-lang-modes entry))

  ;; `C-c '' edits a fence in its own buffer in the language's major mode.  It
  ;; needs edit-indirect, declared in `my-optional-packages' but not required
  ;; here: markdown-mode loads it on demand and reports its absence itself.

  ;; Tables are the one part of Markdown that has to line up in the source, and
  ;; the command that lines them up ships without a binding.
  (keymap-set markdown-mode-map "C-c C-x a" #'markdown-table-align)

  ;; The switch between editing the text and reading the result.  Bound here
  ;; rather than with the formula rendering below because hiding markup works
  ;; whether or not LaTeX is installed.
  (keymap-set markdown-mode-map "C-c C-v" #'my-markdown-preview-mode))


;;; Reading: formulas rendered by LaTeX.

;; `markdown-enable-math' only fontifies a formula -- `$E = mc^2$' stays LaTeX
;; source in a math face.  texfrag renders it, by reusing AUCTeX's preview.el,
;; the same machinery that shows formulas inside a .tex buffer.  It recognises
;; `$...$', `$$...$$', `\(...\)', `\[...\]' and `\begin{env}...\end{env}'.

(defconst init-markdown-math-regexp
  "\\$\\$\\|\\\\\\[\\|\\\\(\\|\\\\begin{[a-z*]+}\\|\\$[^$\n]*\\\\[[:alpha:]]"
  "What a buffer must contain before it is worth running LaTeX over it.

Display math in any of its spellings, a LaTeX environment, or inline math
holding at least one macro.  A sentence mentioning `$5' and `$10' therefore
does not count as a formula, while `$\\vec{E}$' does.")

(defun init-markdown--math-buffer-p ()
  "Return non-nil when the buffer holds a formula texfrag could render."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward init-markdown-math-regexp nil t)))

(defun init-markdown-texfrag-if-available ()
  "Make formula rendering available in the current buffer.

Nothing is rendered here; `my-markdown-preview-mode' does that on request.
Mirrors `init-latex-flyspell-if-available': without `latex' on PATH every
one of texfrag's commands could only fail, so leave the mode off rather
than offer keys that report a missing program."
  (when (executable-find "latex")
    (texfrag-mode 1)))

(define-minor-mode my-markdown-preview-mode
  "Show what the Markdown means instead of how it is written.

Formulas become images, and the characters that exist only to mark up text
-- the `**' around bold, a link's target -- are hidden.  Switching the mode
off puts the source back, which is where a Markdown buffer starts.

The images come from one LaTeX run over the whole buffer, made when the
mode is switched on.  After editing a formula, re-render that one alone
with `preview-at-point' (C-c C-e) instead of leaving and re-entering.

Inline images are left alone in both states: a picture is content, not
markup.  A terminal frame cannot display an image at all, so there the
formulas stay as source and only the markup hiding takes effect."
  :lighter " Preview"
  :interactive (markdown-mode)
  (cond
   (my-markdown-preview-mode
    (markdown-toggle-markup-hiding 1)
    (markdown-toggle-url-hiding 1)
    ;; A buffer with no formula has no reason to pay for a LaTeX run.
    (when (and (bound-and-true-p texfrag-mode)
               (display-images-p)
               (init-markdown--math-buffer-p))
      (texfrag-document)))
   (t
    (markdown-toggle-markup-hiding -1)
    (markdown-toggle-url-hiding -1)
    (when (bound-and-true-p texfrag-mode)
      (preview-clearout-document)))))

(use-package texfrag
  ;; preview.el comes from AUCTeX, which texfrag loads at require time.
  :if (and (package-installed-p 'texfrag) (package-installed-p 'auctex))
  :hook (markdown-mode . init-markdown-texfrag-if-available)

  :custom
  ;; `texfrag-LaTeX-dir' treats an absolute name as the directory to build in,
  ;; rather than creating a `texfrag/' subdirectory beside the file being
  ;; edited.  Generated files belong under `init-var-directory' for the same
  ;; reason backups do: a repository carries configuration, not build output.
  ;; The trade-off is that names come from the file's base name alone, so two
  ;; files both called notes.md share one set of throwaway files.
  (texfrag-subdir (expand-file-name "texfrag" init-var-directory))

  ;; Switching the mode on installs `texfrag-submap' at this prefix in the
  ;; shared `texfrag-mode-map', where it wins over the major mode's keys.  The
  ;; default `C-c C-p' is `markdown-outline-previous', which would stop working
  ;; the moment a formula came into view.  The group holds the rare commands --
  ;; render the whole document, show the LaTeX log -- so three keys deep is
  ;; where it belongs; the two frequent ones are bound directly.
  (texfrag-prefix (kbd "C-c C-x v"))

  :config
  ;; `preview-at-point' is the one key needed while writing a formula: on a
  ;; rendered one it swaps the image back for the source and again for the
  ;; image, and on a formula that was just edited it re-renders that one alone,
  ;; because the neighbouring untouched previews bound the region it takes.
  ;; With nothing rendered yet it does the whole buffer -- texfrag widens the
  ;; region to every fragment it can find.
  (keymap-set markdown-mode-map "C-c C-e" #'preview-at-point))


;;; Supporting packages.

(use-package markdown-toc
  :if (package-installed-p 'markdown-toc)
  :after markdown-mode
  ;; Writes a linked table of contents between its own HTML comment markers and
  ;; rewrites it in place afterwards, so it can be refreshed once the headings
  ;; have moved.  `C-c C-o' on an entry jumps to that heading; `M-g i' does the
  ;; same without a table of contents in the file at all.
  :bind (:map markdown-mode-map
              ("C-c C-x t" . markdown-toc-generate-or-refresh-toc)))

(use-package visual-fill-column
  :if (package-installed-p 'visual-fill-column)
  ;; `visual-line-mode' alone wraps at the window edge, which on a wide frame is
  ;; far past a comfortable measure.  This moves the wrap to `fill-column' -- 88,
  ;; from `init-base' -- without inserting the newlines that would show up in the
  ;; diff.  `C-x f' still sets the measure per buffer.
  :hook (markdown-mode . visual-fill-column-mode)
  :config
  ;; The wrap is a window margin, recomputed from `fill-column' only when the
  ;; window changes.  `C-x f' changes neither, so without this the buffer keeps
  ;; the old measure until the next split or resize refreshes it.
  ;; `visual-fill-column-adjust' is written to be used as advice -- it takes the
  ;; ignored numeric argument `text-scale-adjust' passes -- and does nothing in
  ;; buffers where the mode is off.
  (advice-add 'set-fill-column :after #'visual-fill-column-adjust))

(provide 'init-markdown)

;;; init-markdown.el ends here
