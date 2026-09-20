;;; init-markdown.el --- Markdown writing environment -*- lexical-binding: t; -*-

;; Emacs 31 supplies the Tree-sitter major mode.  It understands CommonMark
;; and the GFM extensions used by README files, so one mode now covers every
;; Markdown extension instead of splitting files between markdown-mode and
;; gfm-mode.  Its two pinned grammar recipes are declared by the library itself;
;; `my-install-packages' installs them along with the external packages.
(require 'cl-lib)
(require 'seq)
(require 'init-latex)
(require 'init-treesit)

(declare-function markdown-ts-mode "markdown-ts-mode")
(declare-function markdown-ts-at-table-p "markdown-ts-mode" (&optional pos quiet))
(declare-function markdown-ts--remove-image-overlays "markdown-ts-mode")
(declare-function markdown-ts--set-hide-markup "markdown-ts-mode" (value))
(declare-function markdown-ts-appear--start "markdown-ts-appear")
(declare-function markdown-ts-appear--stop "markdown-ts-appear")
(declare-function mathjax-available-p "mathjax")
(declare-function valign-table "valign")
(declare-function visual-fill-column-adjust "visual-fill-column")

(defcustom init-markdown-default-render-mode 'live
  "Rendering mode used when a Markdown buffer is opened."
  :type '(choice (const :tag "Live rendering" live)
                 (const :tag "Source only" source)
                 (const :tag "Read-only preview" preview))
  :group 'markdown-ts)

(defcustom init-markdown-table-realign-delay 0.15
  "Idle seconds used to coalesce table layouts after math rendering."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-render-section-numbers t
  "Whether rendered Markdown headings show level badges and section numbers."
  :type 'boolean
  :group 'markdown-ts)

(defcustom init-markdown-heading-number-delay 0.1
  "Idle seconds before rendered Markdown heading numbers are recomputed."
  :type 'number
  :group 'markdown-ts)

(defface init-markdown-heading-level-badge
  '((t (:inherit shadow
        :height 0.8
        :weight normal
        :slant normal
        :box (:line-width -1))))
  "Face for the boxed heading-level digit in rendered Markdown."
  :group 'markdown-ts-faces)

(defvar-local init-markdown-render-mode nil
  "Current Markdown rendering mode: `live', `source', or `preview'.")

(defvar-local init-markdown--table-inline-range-settings nil
  "Range settings added for parsing inline markup in table cells.")

(defvar-local init-markdown--table-realign-timer nil
  "Idle timer for a pending batch of table realignments.")

(defvar-local init-markdown--tables-pending-realign nil
  "Markers identifying tables waiting for one display-only realignment.")

(defvar-local init-markdown--heading-number-overlays nil
  "Display-only overlays supplying heading badges and section numbers.")

(defvar-local init-markdown--heading-number-timer nil
  "Idle timer for recomputing rendered heading numbers.")

(defun init-markdown--configure-heading-faces (&optional _theme)
  "Give Markdown heading levels a visible, theme-independent hierarchy.

_THEME is accepted so this function can also run from
`enable-theme-functions'.  Colors continue to come from the active theme;
relative height, weight, and the final level's slant distinguish the levels."
  (when (facep 'init-markdown-heading-level-badge)
    (let* ((body-height (face-attribute 'default :height nil 'default))
           ;; An integer face height is absolute.  A float would be multiplied
           ;; by the surrounding H1--H6 face and produce different box sizes.
           (badge-height (if (integerp body-height)
                             (round (* body-height 0.8))
                           80)))
      (set-face-attribute 'init-markdown-heading-level-badge nil
                          :inherit 'shadow
                          :family (face-attribute 'default :family nil 'default)
                          :height badge-height
                          :width 'normal
                          :weight 'normal
                          :slant 'normal
                          :box '(:line-width -1))))
  (dolist (spec '((markdown-ts-heading-1 1.55 ultra-bold normal)
                  (markdown-ts-heading-2 1.35 bold normal)
                  (markdown-ts-heading-3 1.20 bold normal)
                  (markdown-ts-heading-4 1.10 semi-bold normal)
                  (markdown-ts-heading-5 1.00 semi-bold normal)
                  (markdown-ts-heading-6 0.95 normal italic)))
    (pcase-let ((`(,face ,height ,weight ,slant) spec))
      (when (facep face)
        (set-face-attribute face nil
                            :inherit 'font-lock-function-name-face
                            :height height
                            :weight weight
                            :slant slant)))))

(defun init-markdown--heading-info (node)
  "Return (LEVEL START END FACE) for Markdown heading NODE."
  (let ((node-type (treesit-node-type node)))
    (cond
     ((equal node-type "atx_heading")
      (let* ((marker (treesit-node-child node 0))
             (marker-type (and marker (treesit-node-type marker)))
             (level (and marker-type
                         (string-match "\\`atx_h\\([1-6]\\)_marker\\'"
                                       marker-type)
                         (string-to-number (match-string 1 marker-type))))
             (content (and (> (treesit-node-child-count node) 1)
                           (treesit-node-child node 1))))
        (when level
          (list level
                (if content
                    (treesit-node-start content)
                  (treesit-node-end marker))
                (if content
                    (treesit-node-end content)
                  (treesit-node-end marker))
                (intern (format "markdown-ts-heading-%d" level))))))
     ((equal node-type "setext_heading")
      (let* ((content (treesit-node-child node 0))
             (underline
              (treesit-node-child node
                                  (1- (treesit-node-child-count node))))
             (level (pcase (and underline (treesit-node-type underline))
                      ("setext_h1_underline" 1)
                      ("setext_h2_underline" 2))))
        (when level
          (let ((end (treesit-node-end content)))
            (while (and (> end (treesit-node-start content))
                        (memq (char-before end) '(?\n ?\r)))
              (setq end (1- end)))
            (list level (treesit-node-start content) end
                  (intern (format "markdown-ts-heading-%d" level))))))))))

(defun init-markdown--clear-heading-numbers ()
  "Delete every rendered heading-number overlay in the current buffer."
  (mapc #'delete-overlay init-markdown--heading-number-overlays)
  (setq init-markdown--heading-number-overlays nil))

(defun init-markdown--refresh-heading-numbers (buffer)
  "Recompute display-only heading numbering in Markdown BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq init-markdown--heading-number-timer nil)
      (init-markdown--clear-heading-numbers)
      (when (and init-markdown-render-section-numbers
                 (memq init-markdown-render-mode '(live preview))
                 (derived-mode-p 'markdown-ts-mode)
                 (treesit-parser-list))
        (let* ((root (treesit-buffer-root-node 'markdown))
               (nodes
                (sort
                 (mapcar #'cdr
                         (treesit-query-capture
                          root
                          '(((atx_heading) @heading)
                            ((setext_heading) @heading))))
                 (lambda (left right)
                   (< (treesit-node-start left) (treesit-node-start right)))))
               (counters (make-vector 6 0)))
          (dolist (node nodes)
            (when-let* ((info (init-markdown--heading-info node))
                        (level (nth 0 info))
                        (start (nth 1 info))
                        (end (nth 2 info))
                        (heading-face (nth 3 info)))
              ;; Fill skipped parent levels with one, increment this level,
              ;; and reset all deeper levels.
              (dotimes (index (1- level))
                (when (zerop (aref counters index))
                  (aset counters index 1)))
              (aset counters (1- level)
                    (1+ (aref counters (1- level))))
              (cl-loop for index from level below 6
                       do (aset counters index 0))
              (let* ((section-number
                      (mapconcat #'number-to-string
                                 (seq-take (append counters nil) level) "."))
                     (badge
                      (propertize (format " %d " level)
                                  'face 'init-markdown-heading-level-badge))
                     (number
                      (propertize section-number 'face heading-face))
                     (overlay (make-overlay start end nil nil nil)))
                (overlay-put overlay 'init-markdown-heading-number t)
                (overlay-put overlay 'priority 20)
                (overlay-put overlay 'before-string
                             (concat number "  "))
                (overlay-put overlay 'after-string
                             (concat " " badge))
                (push overlay init-markdown--heading-number-overlays)))))))))

(defun init-markdown--schedule-heading-numbers (&rest _)
  "Schedule one display-only heading-number refresh after an edit."
  (when (timerp init-markdown--heading-number-timer)
    (cancel-timer init-markdown--heading-number-timer))
  (setq init-markdown--heading-number-timer
        (run-with-idle-timer init-markdown-heading-number-delay nil
                             #'init-markdown--refresh-heading-numbers
                             (current-buffer))))

(defun init-markdown--enable-heading-numbers ()
  "Enable automatically refreshed rendered heading numbers."
  (add-hook 'after-change-functions
            #'init-markdown--schedule-heading-numbers nil t)
  (init-markdown--schedule-heading-numbers))

(defun init-markdown--disable-heading-numbers ()
  "Disable and remove rendered heading numbers in this buffer."
  (remove-hook 'after-change-functions
               #'init-markdown--schedule-heading-numbers t)
  (when (timerp init-markdown--heading-number-timer)
    (cancel-timer init-markdown--heading-number-timer))
  (setq init-markdown--heading-number-timer nil)
  (init-markdown--clear-heading-numbers))

(defun init-markdown-math-preview-available-p ()
  "Return non-nil when all Markdown MathJax preview dependencies exist."
  (and (image-type-available-p 'svg)
       (require 'mathjax nil t)
       (fboundp 'mathjax-available-p)
       (mathjax-available-p)))

(defun init-markdown--setup-table-inline-ranges ()
  "Parse inline Markdown, including math, inside GFM table cells.

Emacs 31 only embeds the `markdown-inline' parser in ordinary `inline' nodes.
The block grammar represents table contents as `pipe_table_cell' nodes, so
without this extra range every `$...$' expression in a table remains plain
source text."
  (unless init-markdown--table-inline-range-settings
    (setq init-markdown--table-inline-range-settings
      (treesit-range-rules
       :embed 'markdown-inline
       :host 'markdown
       :local t
       ;; One parser per table is enough.  A parser per cell (or even per row)
       ;; scales poorly in large tables; the validator below still prevents a
       ;; math span from crossing cell boundaries.
       '((pipe_table) @markdown-inline)))
    (setq-local treesit-range-settings
                (append treesit-range-settings
                        init-markdown--table-inline-range-settings))
    (treesit-update-ranges (point-min) (point-max))))

(defun init-markdown--remove-table-inline-ranges ()
  "Stop maintaining extra inline parsers for table cells."
  (when init-markdown--table-inline-range-settings
    (let ((settings init-markdown--table-inline-range-settings))
      (setq-local treesit-range-settings
                  (seq-remove (lambda (setting) (memq setting settings))
                              treesit-range-settings)))
    (setq init-markdown--table-inline-range-settings nil)
    (treesit-update-ranges (point-min) (point-max))))

(defun init-markdown--table-cell-at (position)
  "Return the Markdown table cell containing POSITION, if any."
  (when-let* ((node (treesit-node-at position 'markdown)))
    (while (and node
                (not (member (treesit-node-type node)
                             '("pipe_table_cell"
                               "pipe_table_delimiter_cell"))))
      (setq node (treesit-node-parent node)))
    node))

(defun init-markdown--latex-block-valid-p (original node)
  "Accept a LaTeX block NODE when it stays inside one table cell.

Emacs 31's ORIGINAL validator requires both delimiters to belong to the same
Markdown `inline' node.  GFM table cells have no such wrapper, so otherwise a
perfectly valid `$...$' or `$$...$$' expression in a cell is rejected."
  (or (funcall original node)
      (when (and node (equal (treesit-node-type node) "latex_block"))
        (let ((start-cell
               (init-markdown--table-cell-at (treesit-node-start node)))
              (end-cell
               (init-markdown--table-cell-at (1- (treesit-node-end node)))))
          (and start-cell end-cell (treesit-node-eq start-cell end-cell))))))

(defun init-markdown--realign-table-after-math (original request data)
  "Run ORIGINAL with REQUEST and DATA, then schedule its table layout."
  (let ((buffer (car request))
        (position (marker-position (cadr request)))
        result)
    (setq result (funcall original request data))
    (when (and position (buffer-live-p buffer))
      (init-markdown--schedule-table-realign buffer position))
    result))

(defun init-markdown--cancel-table-realign ()
  "Cancel and release pending table layout work in the current buffer."
  (when (timerp init-markdown--table-realign-timer)
    (cancel-timer init-markdown--table-realign-timer))
  (setq init-markdown--table-realign-timer nil)
  (dolist (marker init-markdown--tables-pending-realign)
    (set-marker marker nil))
  (setq init-markdown--tables-pending-realign nil))

(defun init-markdown--flush-table-realignments (buffer)
  "Realign the tables queued in BUFFER, once per table."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (let ((markers init-markdown--tables-pending-realign))
        (setq init-markdown--table-realign-timer nil
              init-markdown--tables-pending-realign nil)
        (unwind-protect
            (when (and (memq init-markdown-render-mode '(live preview))
                       (bound-and-true-p valign-mode))
              (dolist (marker markers)
                (when (marker-position marker)
                  (save-excursion
                    (goto-char marker)
                    ;; Layout failure must not turn a successful MathJax
                    ;; render into a formula-preview error.
                    (ignore-errors (valign-table))))))
          (dolist (marker markers)
            (set-marker marker nil)))))))

(defun init-markdown--schedule-table-realign (buffer position)
  "Queue the table at POSITION in BUFFER for one idle-time layout."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and (bound-and-true-p valign-mode)
                 (memq init-markdown-render-mode '(live preview)))
        (when-let* ((start
                     (save-excursion
                       (goto-char position)
                       (when-let* ((at-table (markdown-ts-at-table-p nil t))
                                   (table (cdr at-table)))
                         (treesit-node-start table)))))
            (unless (seq-some
                     (lambda (marker) (equal (marker-position marker) start))
                     init-markdown--tables-pending-realign)
              (push (copy-marker start)
                    init-markdown--tables-pending-realign))
            (when (timerp init-markdown--table-realign-timer)
              (cancel-timer init-markdown--table-realign-timer))
            (setq init-markdown--table-realign-timer
                  (run-with-idle-timer
                   init-markdown-table-realign-delay nil
                   #'init-markdown--flush-table-realignments buffer)))))))

(defun init-markdown--enable-renderers ()
  "Enable markup, math, image, and table rendering in this buffer."
  (init-markdown--setup-table-inline-ranges)
  (init-markdown--enable-heading-numbers)
  (setq-local markdown-ts-inline-images t)
  (when (require 'markdown-ts-appear nil t)
    (unless markdown-ts-appear-mode
      (markdown-ts-appear-mode 1)))
  (when (and (display-graphic-p) (require 'valign nil t))
    (unless valign-mode
      (valign-mode 1))))

(defun init-markdown--disable-renderers ()
  "Disable all display-only Markdown rendering in this buffer."
  (init-markdown--cancel-table-realign)
  (init-markdown--disable-heading-numbers)
  (when (bound-and-true-p markdown-ts-appear-mode)
    (markdown-ts-appear-mode -1))
  (when (bound-and-true-p valign-mode)
    (valign-mode -1))
  (init-markdown--remove-table-inline-ranges)
  (setq-local markdown-ts-inline-images nil)
  (markdown-ts--remove-image-overlays)
  (setq-local markdown-ts-hide-markup nil)
  (markdown-ts--set-hide-markup nil))

(defun my-markdown-render-live ()
  "Use editable live rendering in the current Markdown buffer."
  (interactive)
  (unless (derived-mode-p 'markdown-ts-mode)
    (user-error "This is not a Markdown TS buffer"))
  (read-only-mode -1)
  (init-markdown--enable-renderers)
  ;; Preview mode leaves appear enabled but stops point tracking.
  (when (fboundp 'markdown-ts-appear--start)
    (markdown-ts-appear--start))
  (setq init-markdown-render-mode 'live)
  (font-lock-flush)
  (font-lock-ensure)
  (message "Markdown rendering: live"))

(defun my-markdown-render-source ()
  "Show editable Markdown source without display-time rendering."
  (interactive)
  (unless (derived-mode-p 'markdown-ts-mode)
    (user-error "This is not a Markdown TS buffer"))
  (read-only-mode -1)
  (init-markdown--disable-renderers)
  (setq init-markdown-render-mode 'source)
  (font-lock-flush)
  (font-lock-ensure)
  (message "Markdown rendering: source"))

(defun my-markdown-render-preview ()
  "Show a static, read-only rendered Markdown preview."
  (interactive)
  (unless (derived-mode-p 'markdown-ts-mode)
    (user-error "This is not a Markdown TS buffer"))
  (read-only-mode -1)
  (init-markdown--enable-renderers)
  ;; Keep all markup rendered instead of revealing the element at point.
  (when (fboundp 'markdown-ts-appear--stop)
    (markdown-ts-appear--stop))
  (setq init-markdown-render-mode 'preview)
  (font-lock-flush)
  (font-lock-ensure)
  (read-only-mode 1)
  (message "Markdown rendering: preview (read-only)"))

(defun my-markdown-render-cycle ()
  "Cycle among live rendering, source, and read-only preview modes."
  (interactive)
  (pcase init-markdown-render-mode
    ('live (my-markdown-render-source))
    ('source (my-markdown-render-preview))
    (_ (my-markdown-render-live))))

(defun init-markdown--initialize-render-mode ()
  "Apply `init-markdown-default-render-mode' to a new buffer."
  (add-hook 'kill-buffer-hook #'init-markdown--cancel-table-realign nil t)
  (add-hook 'kill-buffer-hook #'init-markdown--disable-heading-numbers nil t)
  (pcase init-markdown-default-render-mode
    ('source (my-markdown-render-source))
    ('preview (my-markdown-render-preview))
    (_ (my-markdown-render-live))))

(defun init-markdown-mode ()
  "Use `markdown-ts-mode', falling back to `text-mode' without its grammars."
  (if (and (init-treesit-grammar-installed-p 'markdown)
           (init-treesit-grammar-installed-p 'markdown-inline))
      (markdown-ts-mode)
    (text-mode)
    (message "Markdown grammars are missing; run M-x my-install-tree-sitter-grammars")))

(use-package markdown-ts-mode
  :ensure nil
  :defer t
  :mode ("\\.\\(?:md\\|markdown\\|mkd\\|mdown\\|mkdn\\|mdwn\\|mdx\\)\\'"
         . init-markdown-mode)
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
  ;; Rendering is initialized after ordinary Markdown setup hooks have run.
  (add-hook 'markdown-ts-mode-hook
            #'init-markdown--initialize-render-mode 90)
  ;; Keep table geometry independent of surrounding prose faces.  In
  ;; particular, a theme or a future variable-pitch Markdown setup must not
  ;; make equal numbers of spaces occupy different widths.
  (set-face-attribute 'markdown-ts-table nil
                      :inherit '(fixed-pitch markdown-ts-code-block)
                      :extend nil)
  (set-face-attribute 'markdown-ts-table-header nil
                      :inherit '(bold markdown-ts-table))
  ;; Emacs defines all six Markdown heading faces identically.  Preserve the
  ;; theme's heading color while using typography to expose document structure.
  (init-markdown--configure-heading-faces)
  (add-hook 'enable-theme-functions
            #'init-markdown--configure-heading-faces)
  ;; `markdown-ts--latex-block-valid-p' currently rejects math in GFM table
  ;; cells because those cells are not wrapped in Markdown `inline' nodes.
  (unless (advice-member-p #'init-markdown--latex-block-valid-p
                           'markdown-ts--latex-block-valid-p)
    (advice-add 'markdown-ts--latex-block-valid-p :around
                #'init-markdown--latex-block-valid-p))
  ;; Fence names that do not map cleanly to an Emacs major-mode name.
  (dolist (entry '((console sh-mode)
                   (shell-session sh-mode)
                   (zsh bash-ts-mode)))
    (add-to-list 'markdown-ts-code-block-modes entry))
  (keymap-set markdown-ts-mode-map "C-c C-x r"
              #'my-markdown-render-cycle))

(use-package markdown-ts-appear
  :if (package-installed-p 'markdown-ts-appear)
  :after markdown-ts-mode
  :custom
  ;; This configuration uses Helix rather than Evil or Meow.  The generic
  ;; trigger follows point in every modal state and therefore works in both
  ;; insert and normal state.
  (markdown-ts-appear-trigger 'always)
  ;; Missing Node, SVG, or mathjax should disable only formula previews, not
  ;; abort Markdown mode with a file-mode specification error.
  (markdown-ts-appear-enable-math-preview
   (init-markdown-math-preview-available-p))
  (markdown-ts-appear-math-scale 1.1)
  (markdown-ts-appear-link-icon '("" . "↗"))
  (markdown-ts-appear-image-icon '("" . "▧"))
  (markdown-ts-appear-code-fence-style 'connected)
  (markdown-ts-appear-label-caps '("" . ""))
  (markdown-ts-appear-render-callouts t)
  (markdown-ts-appear-block-quote-marker "▎")
  ;; Replace Markdown's ASCII pipes and delimiter row with box-drawing
  ;; characters while keeping the underlying source directly editable.
  (markdown-ts-appear-table-style 'unicode))

(use-package valign
  :if (package-installed-p 'valign)
  :after markdown-ts-mode
  :custom
  ;; Align by actual pixel width, so CJK text and rendered SVG formulas occupy
  ;; the correct amount of space without rewriting the Markdown source.
  (valign-fancy-bar t)
  (valign-lighter nil)
  :config
  ;; Formula SVGs arrive asynchronously and change a cell's pixel width after
  ;; its first layout.  Re-run display-only alignment when that happens.
  (with-eval-after-load 'markdown-ts-appear
    (unless (advice-member-p #'init-markdown--realign-table-after-math
                             'markdown-ts-appear--math-display-result)
      (advice-add 'markdown-ts-appear--math-display-result :around
                  #'init-markdown--realign-table-after-math))))

(use-package visual-fill-column
  :if (package-installed-p 'visual-fill-column)
  :hook (markdown-ts-mode . visual-fill-column-mode)
  :config
  ;; Recenter immediately after `C-x f' changes this buffer's writing width.
  (advice-add 'set-fill-column :after #'visual-fill-column-adjust))

(provide 'init-markdown)

;;; init-markdown.el ends here
