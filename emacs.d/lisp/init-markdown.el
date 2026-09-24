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
(declare-function markdown-ts-appear-start "markdown-ts-appear")
(declare-function markdown-ts-appear-stop "markdown-ts-appear")
(declare-function markdown-ts-appear--active-p "markdown-ts-appear")
(declare-function markdown-ts-appear--update "markdown-ts-appear")
(declare-function markdown-ts-appear-math--delete "markdown-ts-appear" (preview))
(declare-function markdown-ts-appear-math--display "markdown-ts-appear" (preview))
(declare-function markdown-ts-appear-math--refresh "markdown-ts-appear" (&optional force))
(declare-function mathjax-available-p "mathjax")
(declare-function mathjax-display "mathjax" (beg end math &rest options))
(declare-function valign-table "valign")
(declare-function visual-fill-column-adjust "visual-fill-column")

(defcustom init-markdown-default-render-mode 'live
  "Rendering mode used when a Markdown buffer is opened."
  :type '(choice (const :tag "Live rendering" live)
                 (const :tag "Source only" source)
                 (const :tag "Read-only preview" preview))
  :group 'markdown-ts)

(defcustom init-markdown-visual-width nil
  "Fixed visual writing width for Markdown, or nil to use the window edge.
This is deliberately separate from `fill-column': Emacs requires that
variable to remain positive even when no fixed visual width is wanted."
  :type '(choice (const :tag "Wrap at window edge" nil)
                 (integer :tag "Fixed column"))
  :group 'markdown-ts)

(defcustom init-markdown-table-realign-delay 0.15
  "Idle seconds used to coalesce table layouts after math rendering."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-render-section-numbers t
  "Whether rendered Markdown headings show section numbers."
  :type 'boolean
  :group 'markdown-ts)

(defcustom init-markdown-heading-number-delay 0.1
  "Idle seconds before rendered Markdown heading numbers are recomputed."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-render-debounce 0.12
  "Idle seconds before expensive Markdown previews are reconciled."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-render-margin-screens 1
  "Extra window heights rendered above and below the visible Markdown area."
  :type 'natnum
  :group 'markdown-ts)

(defface init-markdown-math-preview
  '((t (:inherit default)))
  "Face shared by native and compatibility Markdown math previews."
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
  "Display-only overlays supplying heading section numbers.")

(defvar-local init-markdown--heading-number-timer nil
  "Idle timer for recomputing rendered heading numbers.")

(defvar-local init-markdown--heading-numbers-dirty nil
  "Non-nil when heading numbers need the next debounced source pass.")

(defvar-local init-markdown--source-index-tick nil
  "Modification tick represented by `init-markdown--source-index-cache'.")

(defvar-local init-markdown--source-index-cache nil
  "Shared source-only Markdown structures for the current modification tick.")

(defvar-local init-markdown--render-dirty nil
  "Non-nil when formula previews need a debounced reconciliation.")

(defvar-local init-markdown--render-timer nil
  "Idle timer for a pending viewport preview reconciliation.")

(defvar markdown-ts-appear-enable-math-preview)
(defvar markdown-ts-appear-mode)
(defvar markdown-ts-appear-math--objects)
(defvar markdown-ts-appear-math--view)
(defvar valign-mode)
(defvar visual-fill-column-mode)

(defun init-markdown--local-change-bounds (beg end)
  "Return conservative line-local rendering bounds around BEG and END."
  (save-restriction
    (widen)
    (cons (save-excursion
            (goto-char (max (point-min) (1- beg)))
            (line-beginning-position))
          (save-excursion
            (goto-char (min (point-max) (max beg end)))
            (min (point-max) (line-beginning-position 2))))))

(defun init-markdown--delete-icon-overlays (beg end)
  "Delete markdown-ts-appear icon overlays intersecting BEG through END."
  (dolist (overlay (overlays-in beg end))
    (when (or (overlay-get overlay 'markdown-ts-appear--image-label)
              (overlay-get overlay 'markdown-ts-appear--link-icon))
      (delete-overlay overlay))))

(defun init-markdown--after-change-locally (_original beg end _old-length)
  "Invalidate only edited lines and defer expensive preview reconciliation."
  (pcase-let ((`(,refresh-beg . ,refresh-end)
               (init-markdown--local-change-bounds beg end)))
    (init-markdown--delete-icon-overlays refresh-beg refresh-end)
    (font-lock-flush refresh-beg refresh-end))
  (setq init-markdown--render-dirty t))

(defun init-markdown--viewport-ranges ()
  "Return visible ranges plus a configurable screen margin for this buffer."
  (let (ranges)
    (dolist (window (get-buffer-window-list (current-buffer) nil t))
      (let ((margin (* init-markdown-render-margin-screens
                       (window-body-height window))))
        (push
         (cons (save-excursion
                 (goto-char (window-start window))
                 (forward-line (- margin))
                 (point))
               (save-excursion
                 (goto-char (or (window-end window t) (point-max)))
                 (forward-line margin)
                 (point)))
         ranges)))
    ranges))

(defun init-markdown--math-in-viewport-p (beg end)
  "Return non-nil when BEG through END intersects a rendered viewport."
  (seq-some (lambda (range)
              (and (< beg (cdr range)) (< (car range) end)))
            (init-markdown--viewport-ranges)))

(defun init-markdown--limit-math-to-viewport (original beg end)
  "Allow ORIGINAL math eligibility only inside the rendered viewport."
  (and (init-markdown--math-in-viewport-p beg end)
       (funcall original beg end)))

(defun init-markdown--defer-dirty-math-refresh (original &optional force)
  "Defer changed-buffer scans by ORIGINAL until the render debounce expires."
  (unless (and init-markdown--render-dirty (not force))
    (funcall original force)))

(defun init-markdown--run-deferred-render (buffer)
  "Reconcile visible formula previews in live Markdown BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (let ((refresh-math init-markdown--render-dirty)
            (refresh-headings init-markdown--heading-numbers-dirty))
        (setq init-markdown--render-timer nil
              init-markdown--render-dirty nil
              init-markdown--heading-numbers-dirty nil)
        (when (derived-mode-p 'markdown-ts-mode)
          ;; Both consumers share the same source index for this edit.
          (when (and refresh-math
                     (bound-and-true-p markdown-ts-appear-mode))
            (markdown-ts-appear-math--refresh t))
          (when refresh-headings
            (init-markdown--refresh-heading-numbers buffer)))))))

(defun init-markdown--schedule-deferred-render (&rest _)
  "Debounce a dirty preview update after command processing or scrolling."
  (when (or init-markdown--render-dirty
            init-markdown--heading-numbers-dirty)
    (when (timerp init-markdown--render-timer)
      (cancel-timer init-markdown--render-timer))
    (setq init-markdown--render-timer
          (run-with-idle-timer init-markdown-render-debounce nil
                               #'init-markdown--run-deferred-render
                               (current-buffer)))))

(defun init-markdown--viewport-changed (window _start)
  "Schedule formula reconciliation when WINDOW scrolls this buffer."
  (when-let* ((buffer (window-buffer window))
              ((buffer-live-p buffer)))
    (with-current-buffer buffer
      (when (derived-mode-p 'markdown-ts-mode)
        (setq init-markdown--render-dirty t)
        (init-markdown--schedule-deferred-render)))))

(defun init-markdown--cancel-deferred-render ()
  "Cancel a pending viewport render in the current buffer."
  (when (timerp init-markdown--render-timer)
    (cancel-timer init-markdown--render-timer))
  (setq init-markdown--render-timer nil
        init-markdown--render-dirty nil
        init-markdown--heading-numbers-dirty nil))

(defun init-markdown--configure-heading-faces (&optional _theme)
  "Give Markdown heading levels a visible, theme-independent hierarchy.

_THEME is accepted so this function can also run from
`enable-theme-functions'.  Colors continue to come from the active theme;
relative height, weight, and the final level's slant distinguish the levels."
  (dolist (spec '((markdown-ts-heading-1 1.80 bold normal)
                  (markdown-ts-heading-2 1.62 bold normal)
                  (markdown-ts-heading-3 1.46 bold normal)
                  (markdown-ts-heading-4 1.31 bold normal)
                  (markdown-ts-heading-5 1.18 bold normal)
                  (markdown-ts-heading-6 1.06 normal italic)))
    (pcase-let ((`(,face ,height ,weight ,slant) spec))
      (when (facep face)
        (set-face-attribute face nil
                            :inherit 'font-lock-function-name-face
                            :height height
                            :weight weight
                            :slant slant)))))

(defun init-markdown--clear-heading-numbers ()
  "Delete every rendered heading-number overlay in the current buffer."
  (mapc #'delete-overlay init-markdown--heading-number-overlays)
  (setq init-markdown--heading-number-overlays nil))

(defun init-markdown--source-index-value (key producer)
  "Return cached KEY, computing it with PRODUCER once per buffer edit."
  (let ((tick (buffer-chars-modified-tick)))
    (unless (equal tick init-markdown--source-index-tick)
      (setq init-markdown--source-index-tick tick
            init-markdown--source-index-cache nil))
    (if-let* ((entry (plist-member init-markdown--source-index-cache key)))
        (cadr entry)
      (let ((value (funcall producer)))
        (setq init-markdown--source-index-cache
              (plist-put init-markdown--source-index-cache key value))
        value))))

(defun init-markdown--compute-math-source-ranges ()
  "Return source ranges delimited by LaTeX math markers in this buffer.
This scanner uses source text only; it never queries Tree-sitter from a timer
or edit hook."
  (let (fence-char fence-length ranges)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (cond
         (fence-char
          (beginning-of-line)
          (when (looking-at "^ \\{0,3\\}\\(`+\\|~+\\)")
            (let ((token (match-string-no-properties 1)))
              (when (and (eq (aref token 0) fence-char)
                         (>= (length token) fence-length))
                (setq fence-char nil fence-length nil))))
          (forward-line 1))
         ((and (bolp) (looking-at "^ \\{0,3\\}\\(`+\\|~+\\)"))
          (let ((token (match-string-no-properties 1)))
            (when (>= (length token) 3)
              (setq fence-char (aref token 0)
                    fence-length (length token))))
          (forward-line 1))
         ((and (bolp) (looking-at "\\(?:    \\|\t\\)"))
          (forward-line 1))
         (t
          (let ((line-end (line-end-position)))
            (if (not (re-search-forward
                      (rx (or (+ "`") "\\(" "\\[" "$$")) line-end t))
                (forward-line 1)
              (let ((token (match-string-no-properties 0)))
                (if (string-prefix-p "`" token)
                    (let ((quoted (regexp-quote token)))
                      (unless (re-search-forward quoted line-end t)
                        (goto-char line-end)))
                  (let* ((beg (match-beginning 0))
                         (closing (pcase token
                                    ("\\(" "\\)")
                                    ("\\[" "\\]")
                                    (_ "$$"))))
                    (unless (init-markdown--escaped-position-p beg)
                      (when-let* ((end
                                   (init-markdown--search-latex-closing-delimiter
                                    closing)))
                        (push (cons beg end) ranges)))))))))))
      (nreverse ranges))))

(defun init-markdown--math-source-ranges ()
  "Return cached source-only LaTeX math ranges for the current buffer text."
  (init-markdown--source-index-value
   :math #'init-markdown--compute-math-source-ranges))

(defun init-markdown--range-overlaps-p (beg end ranges)
  "Return non-nil when BEG through END overlaps one of RANGES."
  (seq-some (lambda (range)
              (and (< beg (cdr range)) (< (car range) end)))
            ranges))

(defun init-markdown--position-in-ranges-p (position ranges)
  "Return non-nil when POSITION lies in one of RANGES."
  (seq-some (lambda (range)
              (and (<= (car range) position) (< position (cdr range))))
            ranges))

(defun init-markdown--compute-source-headings ()
  "Return Markdown headings as (LEVEL START END), using source text only.
Math and literal code are excluded without consulting the live Tree-sitter
parser, so malformed Markdown-looking content inside formulas cannot affect
section numbering or crash the external scanner."
  (let* ((math-ranges (init-markdown--math-source-ranges))
         (code-ranges (init-markdown--code-source-ranges math-ranges))
        headings)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((line-beg (line-beginning-position))
              (line-end (line-end-position)))
          (unless (or (init-markdown--position-in-ranges-p
                       line-beg code-ranges)
                      (init-markdown--range-overlaps-p
                       line-beg (max (1+ line-beg) line-end) math-ranges))
            (if (looking-at
                 "^[ \t]\\{0,3\\}\\(#\\{1,6\\}\\)[ \t]+\\(.+?\\)[ \t]*$")
                (push (list (length (match-string-no-properties 1))
                            (match-beginning 2) (match-end 2))
                      headings)
              (when (looking-at
                     "^[ \t]\\{0,3\\}\\([^ \t\n].*?\\)[ \t]*$")
                (let ((content-start (match-beginning 1))
                      (content-end (match-end 1)))
                  (save-excursion
                    (forward-line 1)
                    (when (and (< (point) (point-max))
                               (not (init-markdown--position-in-ranges-p
                                     (point) code-ranges))
                               (not (init-markdown--range-overlaps-p
                                     (point) (line-end-position) math-ranges))
                               (looking-at
                                "^[ \t]\\{0,3\\}\\(=+\\|-+\\)[ \t]*$"))
                      (push (list (if (eq (char-after (match-beginning 1)) ?=)
                                      1 2)
                                  content-start content-end)
                            headings))))))))
        (forward-line 1)))
    (nreverse headings)))

(defun init-markdown--source-headings ()
  "Return cached source-only headings for the current buffer text."
  (init-markdown--source-index-value
   :headings #'init-markdown--compute-source-headings))

(defun init-markdown--reset-parser-ranges ()
  "Keep the live Markdown parsers on their stable full-buffer range.
Incrementally changing included ranges corrupts the Markdown external scanner
in Emacs 31 after edits near EOF or inside block quotes."
  (dolist (parser (treesit-parser-list nil 'markdown))
    (when (treesit-parser-included-ranges parser)
      (treesit-parser-set-included-ranges parser nil))))

(defun init-markdown--refresh-heading-numbers (buffer)
  "Recompute display-only heading numbering in Markdown BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq init-markdown--heading-number-timer nil)
      (setq init-markdown--heading-numbers-dirty nil)
      (init-markdown--clear-heading-numbers)
      (when (and init-markdown-render-section-numbers
                 (memq init-markdown-render-mode '(live preview))
                 (derived-mode-p 'markdown-ts-mode))
        (let ((counters (make-vector 6 0)))
          (dolist (info (init-markdown--source-headings))
            (let ((level (nth 0 info))
                  (start (nth 1 info))
                  (end (nth 2 info)))
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
                      ;; H1 is an unnumbered document title.  Numbering starts
                      ;; at H2, so H2 is 1, 2, ... and H3 is 1.1, 1.2, ... .
                      (when (> level 1)
                        (mapconcat
                         #'number-to-string
                         (seq-take (cdr (append counters nil)) (1- level))
                         ".")))
                     ;; The overlay string inherits the heading face from the
                     ;; covered text.  Applying the same relative-height face
                     ;; here as well would scale the number a second time.
                     (number section-number)
                     (overlay (and number
                                   (make-overlay start end nil nil nil))))
                (when overlay
                  (overlay-put overlay 'init-markdown-heading-number t)
                  (overlay-put overlay 'priority 20)
                  (overlay-put overlay 'before-string (concat number "  "))
                  (push overlay
                        init-markdown--heading-number-overlays))))))))))

(defun init-markdown--schedule-heading-numbers (&rest _)
  "Mark source-only heading numbers for the next debounced refresh."
  (setq init-markdown--heading-numbers-dirty t))

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
  (setq init-markdown--heading-number-timer nil
        init-markdown--heading-numbers-dirty nil)
  (init-markdown--clear-heading-numbers))

(defun init-markdown-math-preview-available-p ()
  "Return non-nil when all Markdown MathJax preview dependencies exist."
  (and (image-type-available-p 'svg)
       (require 'mathjax nil t)
       (fboundp 'mathjax-available-p)
       (mathjax-available-p)))

(defun init-markdown--escaped-position-p (position)
  "Return non-nil when the character at POSITION is backslash-escaped."
  (let ((cursor (1- position))
        (count 0))
    (while (and (>= cursor (point-min))
                (eq (char-after cursor) ?\\))
      (setq count (1+ count)
            cursor (1- cursor)))
    (cl-oddp count)))

(defun init-markdown--compute-code-source-ranges (&optional math-ranges)
  "Return fenced, indented, and inline code ranges using source text only."
  (unless math-ranges
    (setq math-ranges (init-markdown--math-source-ranges)))
  (let (fence-beg fence-char fence-length fence-ranges code-ranges)
    (save-excursion
      ;; Find fenced blocks first.  A closing fence must use the same character
      ;; and be at least as long as its opener.
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((line-beg (line-beginning-position))
              (line-end (line-end-position)))
          (when (and (not (init-markdown--range-overlaps-p
                           line-beg (max (1+ line-beg) line-end) math-ranges))
                     (looking-at "^ \\{0,3\\}\\(`+\\|~+\\)"))
            (let* ((token (match-string-no-properties 1))
                   (character (aref token 0))
                   (length (length token)))
              (cond
               ((and fence-beg (eq character fence-char)
                     (>= length fence-length))
                (push (cons fence-beg (min (point-max) (1+ line-end)))
                      fence-ranges)
                (setq fence-beg nil fence-char nil fence-length nil))
               ((and (null fence-beg) (>= length 3))
                (setq fence-beg line-beg
                      fence-char character
                      fence-length length)))))
          (forward-line 1)))
      (when fence-beg
        (push (cons fence-beg (point-max)) fence-ranges))
      (setq fence-ranges (nreverse fence-ranges)
            code-ranges (copy-sequence fence-ranges))
      ;; Find line-local inline code and indented code outside fenced blocks.
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((line-beg (line-beginning-position))
              (line-end (line-end-position)))
          (unless (or (init-markdown--position-in-ranges-p
                       line-beg fence-ranges)
                      (init-markdown--range-overlaps-p
                       line-beg (max (1+ line-beg) line-end) math-ranges))
            (if (looking-at "\\(?:    \\|\t\\)")
                (push (cons line-beg (min (point-max) (1+ line-end)))
                      code-ranges)
              (let (opener-beg opener-length)
                (while (re-search-forward "`+" line-end t)
                  (let ((run-beg (match-beginning 0))
                        (run-length (- (match-end 0) (match-beginning 0))))
                    (cond
                     ((null opener-beg)
                      (setq opener-beg run-beg opener-length run-length))
                     ((= run-length opener-length)
                      (push (cons opener-beg (match-end 0)) code-ranges)
                      (setq opener-beg nil opener-length nil))))))))
          (forward-line 1)))
    (sort code-ranges (lambda (left right) (< (car left) (car right)))))))

(defun init-markdown--code-source-ranges (&optional math-ranges)
  "Return cached source-only literal-code ranges for the current buffer text."
  (if math-ranges
      ;; Callers building the shared index already have the matching math pass.
      (init-markdown--source-index-value
       :code (lambda ()
               (init-markdown--compute-code-source-ranges math-ranges)))
    (init-markdown--source-index-value
     :code #'init-markdown--compute-code-source-ranges)))

(defun init-markdown--code-at-p (position)
  "Return non-nil when POSITION belongs to literal Markdown code.
This check is intentionally independent of Tree-sitter."
  (let ((math-ranges (init-markdown--math-source-ranges)))
    (init-markdown--position-in-ranges-p
     position (init-markdown--code-source-ranges math-ranges))))

(defun init-markdown--search-latex-closing-delimiter (delimiter)
  "Find the next unescaped DELIMITER and return its end.
Markdown may misparse code syntax inside math, so its code nodes cannot
decide whether a math closing delimiter is valid."
  (catch 'found
    (while (search-forward delimiter nil t)
      (let ((start (- (point) (length delimiter))))
        (unless (init-markdown--escaped-position-p start)
          (throw 'found (point)))))))

(defun init-markdown--math-preview-at (beg end source)
  "Return an existing Markdown math preview for SOURCE from BEG through END."
  (seq-find
   (lambda (preview)
     (and (overlay-buffer preview)
          (= (overlay-start preview) beg)
          (= (overlay-end preview) end)
          (equal source
                 (overlay-get preview 'markdown-ts-appear-math--source))))
   markdown-ts-appear-math--objects))

(defun init-markdown--block-quote-depth-before (position)
  "Return the Markdown block-quote depth immediately before POSITION."
  (save-excursion
    (goto-char position)
    (let ((prefix (buffer-substring-no-properties
                   (line-beginning-position) position)))
      (when (string-match-p
             "\\`[ \t]*\\(?:>[ \t]?\\)+\\'" prefix)
        (cl-count ?> prefix)))))

(defun init-markdown--normalize-quoted-math (math opening-position)
  "Remove quote prefixes from MATH copied at OPENING-POSITION.
Only the string sent to MathJax is changed; source text and overlay bounds keep
their original Markdown block-quote markers."
  (if-let* ((depth (init-markdown--block-quote-depth-before
                    opening-position))
            ((> depth 0)))
      (let ((prefix-pattern
             (concat "^"
                     (mapconcat (lambda (_level) "[ \t]*>[ \t]?")
                                (number-sequence 1 depth) ""))))
        (replace-regexp-in-string prefix-pattern "" math))
    math))

(defun init-markdown--latex-math-containing-range-p (beg end)
  "Return non-nil when BEG through END lies inside delimiter-based math."
  (seq-some
   (lambda (preview)
     (and (overlay-buffer preview)
          (overlay-get preview 'init-markdown-latex-delimiter-math)
          (<= (overlay-start preview) beg)
          (<= end (overlay-end preview))))
   markdown-ts-appear-math--objects))

(defun init-markdown--skip-link-fontification-in-latex-math
    (original node &rest arguments)
  "Call ORIGINAL unless NODE is a false Markdown link inside LaTeX math."
  (unless (init-markdown--latex-math-containing-range-p
           (treesit-node-start node) (treesit-node-end node))
    (apply original node arguments)))

(defun init-markdown--scan-latex-delimiter-math (original)
  "Run ORIGINAL, then supplement its delimiter-based math previews."
  ;; The native scanner knows nothing about compatibility previews and would
  ;; delete all of them on every buffer edit.  Detach them while it reconciles
  ;; native latex_block objects, then restore the still-live overlays so the
  ;; source scan below can reuse their rendered SVGs.
  (let ((compatibility-previews
         (seq-filter
          (lambda (preview)
            (overlay-get preview 'init-markdown-latex-delimiter-math))
          markdown-ts-appear-math--objects)))
    (setq markdown-ts-appear-math--objects
          (seq-remove
           (lambda (preview)
             (overlay-get preview 'init-markdown-latex-delimiter-math))
           markdown-ts-appear-math--objects))
    (unwind-protect
        (funcall original)
      (setq markdown-ts-appear-math--objects
            (append markdown-ts-appear-math--objects
                    (seq-filter #'overlay-buffer compatibility-previews)))))
  ;; The current markdown-inline grammar treats these delimiters as ordinary
  ;; backslash escapes.  Its block ranges can also split multiline $$ math at
  ;; a Setext-like `=' line.  Supplement the query with a source scan.
  (let ((current (make-hash-table :test #'eq))
        (code-ranges (init-markdown--code-source-ranges))
        newly-created-ranges)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward (rx (or "\\(" "\\[" "$$")) nil t)
        (let* ((beg (match-beginning 0))
               (opening (match-string-no-properties 0))
               (closing (pcase opening
                          ("\\(" "\\)")
                          ("\\[" "\\]")
                          (_ "$$"))))
          (if (or (init-markdown--escaped-position-p beg)
                  (init-markdown--position-in-ranges-p beg code-ranges))
              (goto-char (match-end 0))
            (let ((content-beg (match-end 0))
                  (end (init-markdown--search-latex-closing-delimiter closing)))
              (if (not end)
                  (goto-char content-beg)
                (let* ((source (buffer-substring-no-properties beg end))
                       (preview
                        (init-markdown--math-preview-at beg end source)))
                  (unless preview
                    (setq preview (make-overlay beg end nil t nil))
                    (overlay-put preview 'category 'mathjax)
                    (overlay-put preview 'evaporate t)
                    (overlay-put preview
                                 'init-markdown-latex-delimiter-math t)
                    (overlay-put preview 'markdown-ts-appear-math--source
                                 source)
                    (overlay-put preview 'markdown-ts-appear-math--input
                                 (list (init-markdown--normalize-quoted-math
                                        (buffer-substring-no-properties
                                         content-beg
                                         (- end (length closing)))
                                        beg)
                                       (not (null (member opening
                                                          '("\\[" "$$"))))))
                    (push preview markdown-ts-appear-math--objects)
                    (push (cons beg end) newly-created-ranges))
                  (when (overlay-get
                         preview 'init-markdown-latex-delimiter-math)
                    (puthash preview t current)))))))))
    (dolist (preview (copy-sequence markdown-ts-appear-math--objects))
      (when (and (overlay-get preview
                              'init-markdown-latex-delimiter-math)
                 (not (gethash preview current)))
        (markdown-ts-appear-math--delete preview)))
    ;; The inline parser may already have fontified `[... ]' inside the formula
    ;; as a shortcut link before this compatibility overlay existed.  Re-run
    ;; fontification now that the link fontifiers can recognize the math range.
    (dolist (range newly-created-ranges)
      (font-lock-flush (car range) (cdr range))
      (font-lock-ensure (car range) (cdr range)))))

(defun init-markdown--sync-latex-delimiter-visibility (preview)
  "Reveal both delimiter backslashes while compatibility PREVIEW is edited."
  (when-let* (((overlay-get preview 'init-markdown-latex-delimiter-math))
              (source (overlay-get preview 'markdown-ts-appear-math--source))
              ((or (string-prefix-p "\\(" source)
                   (string-prefix-p "\\[" source))))
    (let* ((beg (overlay-start preview))
           (end (overlay-end preview))
           (visible
            (and (memq #'markdown-ts-appear--update post-command-hook)
                 (<= beg (point))
                 (< (point) end))))
      ;; Font-lock can hide the backslashes again as point moves between
      ;; semantic children of the same formula.  Do not skip this correction
      ;; merely because the formula's visible/editing state is unchanged.
      (with-silent-modifications
        (dolist (position (list beg (- end 2)))
          (if visible
              (when (get-text-property position 'invisible)
                (remove-text-properties position (1+ position)
                                        '(invisible nil)))
            (unless (eq (get-text-property position 'invisible)
                        'markdown-ts--markup)
              (put-text-property position (1+ position)
                                 'invisible 'markdown-ts--markup)))))
      (overlay-put preview 'init-markdown-delimiters-visible visible))))

(defun init-markdown--normalize-math-preview-face (original preview)
  "Run ORIGINAL and normalize PREVIEW's face and editable delimiters."
  (funcall original preview)
  (unless (overlay-get preview 'mathjax-error)
    ;; Besides keeping SVG `currentColor' stable, this masks false Setext
    ;; heading fontification while a multiline formula is being edited.
    (overlay-put preview 'face 'init-markdown-math-preview))
  (init-markdown--sync-latex-delimiter-visibility preview))

(defun init-markdown--request-latex-delimiter-math
    (original preview math display-p)
  "Render compatibility PREVIEW, otherwise call ORIGINAL.
MATH is delimiter-free; DISPLAY-P selects `\\[...]' and `$$...$$' display math."
  (if (not (overlay-get preview 'init-markdown-latex-delimiter-math))
      (funcall original preview math display-p)
    (let ((target (current-buffer))
          (source (overlay-get preview 'markdown-ts-appear-math--source))
          (staging (generate-new-buffer " *init-markdown-latex-math*")))
      (overlay-put preview 'markdown-ts-appear-math--buffer staging)
      (with-current-buffer staging
        (insert source)
        (condition-case err
            (mathjax-display
             (point-min) (point-max) math :options (list :display display-p)
             :after
             (lambda (rendered)
               (unwind-protect
                   (if (not (eq (overlay-buffer preview) target))
                       nil
                     (with-current-buffer target
                       (let ((beg (overlay-start preview))
                             (end (overlay-end preview)))
                         (if (and markdown-ts-appear-enable-math-preview
                                  (markdown-ts-appear--active-p)
                                  (overlay-get
                                   preview 'init-markdown-latex-delimiter-math)
                                  (equal source
                                         (buffer-substring-no-properties beg end)))
                             (progn
                               (overlay-put preview
                                            'markdown-ts-appear-math--image
                                            (overlay-get rendered 'display))
                               (overlay-put preview 'mathjax-error
                                            (overlay-get rendered 'mathjax-error))
                               (setq markdown-ts-appear-math--view nil)
                               (markdown-ts-appear-math--display preview)
                               (init-markdown--schedule-table-realign
                                target beg))
                           (markdown-ts-appear-math--delete preview)))))
                 (overlay-put preview 'markdown-ts-appear-math--buffer nil)
                 (delete-overlay rendered)
                 (when (buffer-live-p staging)
                   (kill-buffer staging)))))
          (error
           (overlay-put preview 'markdown-ts-appear-math--buffer nil)
           (kill-buffer staging)
           (message "Markdown MathJax preview failed: %s"
                    (error-message-string err))))))))

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
  (when (fboundp 'markdown-ts-appear-start)
    (markdown-ts-appear-start))
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
  (when (fboundp 'markdown-ts-appear-stop)
    (markdown-ts-appear-stop))
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
  (add-hook 'kill-buffer-hook #'init-markdown--cancel-deferred-render nil t)
  (add-hook 'post-command-hook #'init-markdown--schedule-deferred-render 100 t)
  (add-hook 'window-scroll-functions #'init-markdown--viewport-changed nil t)
  (init-markdown--reset-parser-ranges)
  (setq init-markdown--render-dirty t)
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
  (markdown-ts-appear-link-icon "")
  (markdown-ts-appear-image-icon "")
  (markdown-ts-appear-code-fence-style 'connected)
  (markdown-ts-appear-label-caps '("" . ""))
  (markdown-ts-appear-render-callouts t)
  (markdown-ts-appear-block-quote-marker "▎")
  ;; Replace Markdown's ASCII pipes and delimiter row with box-drawing
  ;; characters while keeping the underlying source directly editable.
  (markdown-ts-appear-table-style 'unicode)
  :config
  ;; Follow mature viewport renderers: edits invalidate nearby lines, formula
  ;; scans are debounced, and image previews are limited to visible windows.
  (unless (advice-member-p #'init-markdown--after-change-locally
                           'markdown-ts-appear--after-change)
    (advice-add 'markdown-ts-appear--after-change :around
                #'init-markdown--after-change-locally))
  (unless (advice-member-p #'init-markdown--defer-dirty-math-refresh
                           'markdown-ts-appear-math--refresh)
    (advice-add 'markdown-ts-appear-math--refresh :around
                #'init-markdown--defer-dirty-math-refresh))
  (unless (advice-member-p #'init-markdown--limit-math-to-viewport
                           'markdown-ts-appear-math--eligible-p)
    (advice-add 'markdown-ts-appear-math--eligible-p :around
                #'init-markdown--limit-math-to-viewport))
  ;; The Markdown inline grammar currently recognizes dollar-delimited math
  ;; but treats LaTeX's \(...\) and \[...\] forms as backslash escapes.
  (unless (advice-member-p #'init-markdown--scan-latex-delimiter-math
                           'markdown-ts-appear-math--scan)
    (advice-add 'markdown-ts-appear-math--scan :around
                #'init-markdown--scan-latex-delimiter-math))
  (unless (advice-member-p #'init-markdown--request-latex-delimiter-math
                           'markdown-ts-appear-math--request)
    (advice-add 'markdown-ts-appear-math--request :around
                #'init-markdown--request-latex-delimiter-math))
  (unless (advice-member-p #'init-markdown--normalize-math-preview-face
                           'markdown-ts-appear-math--display)
    (advice-add 'markdown-ts-appear-math--display :around
                #'init-markdown--normalize-math-preview-face))
  ;; The markdown-inline grammar does not understand `\[...\]' or `\(...\)'
  ;; and can misclassify TeX brackets inside them as Markdown links.  Suppress
  ;; every link-specific fontifier for nodes covered by a compatibility math
  ;; overlay; genuine links outside formulas continue through unchanged.
  (dolist (fontifier '(markdown-ts--fontify-delimiter
                       markdown-ts--fontify-link-node
                       markdown-ts--fontify-link-destination
                       markdown-ts--fontify-image
                       markdown-ts--fontify-autolink))
    (unless (advice-member-p
             #'init-markdown--skip-link-fontification-in-latex-math fontifier)
      (advice-add fontifier :around
                  #'init-markdown--skip-link-fontification-in-latex-math))))

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

(defun init-markdown--sync-visual-fill-column (&rest _)
  "Apply `init-markdown-visual-width' to the current Markdown buffer."
  (when (and (derived-mode-p 'markdown-ts-mode)
             (require 'visual-fill-column nil t))
    (if (and (integerp init-markdown-visual-width)
             (> init-markdown-visual-width 0))
        (progn
          (setq-local visual-fill-column-width init-markdown-visual-width)
          (if visual-fill-column-mode
              (visual-fill-column-adjust)
            (visual-fill-column-mode 1)))
      (when visual-fill-column-mode
        (visual-fill-column-mode -1)))))

(use-package visual-fill-column
  :if (package-installed-p 'visual-fill-column)
  :hook (markdown-ts-mode . init-markdown--sync-visual-fill-column)
  :config
  ;; Remove the pre-zero-default hook left by older revisions of this config.
  (remove-hook 'markdown-ts-mode-hook #'visual-fill-column-mode)
  (when (advice-member-p #'visual-fill-column-adjust 'set-fill-column)
    (advice-remove 'set-fill-column #'visual-fill-column-adjust)))

(provide 'init-markdown)

;;; init-markdown.el ends here
