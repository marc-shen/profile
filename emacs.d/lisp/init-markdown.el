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

(defcustom init-markdown-render-debounce 0.35
  "Idle seconds before expensive Markdown previews are reconciled."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-math-prewarm-batch-size 8
  "Maximum MathJax requests started in one Markdown render pass."
  :type '(integer 1 *)
  :group 'markdown-ts)

(defcustom init-markdown-math-prewarm-delay 0.08
  "Idle seconds between batches of background MathJax requests."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-math-fast-delay 0.03
  "Idle seconds before a newly closed formula gets priority rendering."
  :type 'number
  :group 'markdown-ts)

(defcustom init-markdown-math-fast-max-chars 8192
  "Maximum source length checked for a just-closed formula."
  :type 'natnum
  :group 'markdown-ts)

(defface init-markdown-math-preview
  '((t (:inherit default)))
  "Face shared by native and compatibility Markdown math previews."
  :group 'markdown-ts-faces)

(defvar-local init-markdown-render-mode nil
  "Current Markdown rendering mode: `live', `source', or `preview'.")

(defvar-local init-markdown--selective-rendering nil
  "Non-nil when only headings, tables and formulas are rendered.")
(defvar-local init-markdown--last-heading-line nil)

(defun init-markdown--selective-active-p (&rest _)
  "Allow the retained math/table helpers without enabling Appear mode."
  init-markdown--selective-rendering)

(defun init-markdown--selective-math-eligible (original beg end)
  "Keep the formula at point editable even before its first preview exists."
  (and (not (and init-markdown--selective-rendering
                 (eq init-markdown-render-mode 'live)
                 (<= beg (point)) (< (point) end)))
       (funcall original beg end)))

(defun init-markdown--dispose-selective-math ()
  "Release pending formula processes when the buffer or mode is closed."
  (when init-markdown--selective-rendering
    (markdown-ts-appear-math--teardown)))

(defun init-markdown--selective-after-change (beg end old-length)
  "Schedule local formula and heading updates after an edit."
  (init-markdown--after-change-locally nil beg end old-length))

(defun init-markdown--clear-edited-math (beg end)
  "Invalidate only formula overlays intersecting the actual edit."
  (dolist (preview (overlays-in beg end))
    (when (and (overlay-get preview 'markdown-ts-appear-math--source)
               (< (overlay-start preview) end)
               (> (overlay-end preview) beg))
      (markdown-ts-appear-math--delete preview))))

(defun init-markdown--selective-point-update ()
  "Reveal only the formula or heading being edited, without querying prose."
  (let* ((preview (and (eq init-markdown-render-mode 'live)
                       (seq-find
                        (lambda (ov)
                          (overlay-get ov 'markdown-ts-appear-math--source))
                        (overlays-at (point)))))
         (beg (and preview (overlay-start preview)))
         (end (and preview (overlay-end preview)))
         (old markdown-ts-appear--region))
    (unless (and (equal beg (and old (marker-position (car old))))
                 (equal end (and old (marker-position (cdr old)))))
      (when old
        (set-marker (car old) nil)
        (set-marker (cdr old) nil))
      (setq markdown-ts-appear--region
            (and beg (cons (copy-marker beg) (copy-marker end t))))))
  (let ((heading (save-excursion
                   (beginning-of-line)
                   (cond
                    ((looking-at "[ \t]*\\(?:>[ \t]?\\)*#\\{1,6\\}[ \t]")
                     (point))
                    ((looking-at "[ \t]*\\(?:=+\\|-+\\)[ \t]*$")
                     (line-beginning-position 0))
                    ((save-excursion
                       (forward-line 1)
                       (looking-at "[ \t]*\\(?:=+\\|-+\\)[ \t]*$"))
                     (point))))))
    (unless (equal heading init-markdown--last-heading-line)
      (dolist (pos (list heading init-markdown--last-heading-line))
        (when (and pos (<= pos (point-max)))
          (save-excursion
            (goto-char pos)
            (font-lock-flush (line-beginning-position) (line-beginning-position 3)))))
      (setq init-markdown--last-heading-line heading))))

(defun init-markdown--fontify-selected-heading (original node &rest args)
  "Hide heading markup outside the heading currently being edited."
  (let* ((heading (or (treesit-parent-until
                      node "\\`\\(?:atx_heading\\|setext_heading\\)\\'" t)
                     node))
         (markdown-ts-hide-markup
         (and init-markdown--selective-rendering
              (not (and (eq init-markdown-render-mode 'live)
                        init-markdown--last-heading-line
                        (<= (save-excursion
                              (goto-char (treesit-node-start heading))
                              (line-beginning-position))
                            init-markdown--last-heading-line)
                        (< init-markdown--last-heading-line
                           (treesit-node-end heading)))))))
    (apply original node args)))

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
  "Idle timer for a pending preview reconciliation.")

(defvar-local init-markdown--math-prewarm-timer nil
  "Idle timer for rendering the next batch of Markdown formulas.")

(defvar-local init-markdown--math-fast-timer nil
  "Idle timer for a newly closed formula near point.")

(defvar-local init-markdown--math-fast-marker nil
  "Marker immediately after the most recently typed math closer.")

(defvar-local init-markdown--math-edit-before nil
  "Non-nil when the pre-edit text or overlays require a formula rescan.")

(defvar-local init-markdown--heading-edit-before nil
  "Non-nil when the pre-edit text may change section numbering.")

(defvar-local init-markdown--fence-edit-before nil)

(defvar-local init-markdown--plain-edit-tick nil
  "Buffer tick of a word insertion needing no Markdown point re-query.")

(defvar-local init-markdown--plain-edit-end nil
  "End position of the last plain word insertion.")

(defvar init-markdown--math-request-budget nil
  "Remaining MathJax requests in the current formula refresh pass.")

(defvar markdown-ts-appear-enable-math-preview)
(defvar markdown-ts-appear-mode)
(defvar markdown-ts-appear-math--objects)
(defvar markdown-ts-appear-math--scan-tick)
(defvar markdown-ts-appear--region)
(defvar markdown-ts-appear-math--view)
(defvar valign-mode)
(defvar visual-fill-column-mode)
(defvar flyspell-delay-use-timer)
(defvar flyspell-check-changes)
(defvar flyspell-mode)

(defun init-markdown--configure-nonblocking-flyspell ()
  "Check edited words after leaving them, without waiting in a key hook."
  (setq-local flyspell-delay-use-timer t)
  (setq-local flyspell-check-changes t)
  (when (bound-and-true-p flyspell-mode)
    (remove-hook 'post-command-hook #'flyspell-post-command-hook t)
    (add-hook 'post-command-hook #'flyspell-check-changes t t)))

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

(defun init-markdown--math-syntax-p (text)
  "Return non-nil when TEXT can change math or literal-block boundaries."
  (string-match-p (rx (any "$" "\\" "`" "~")) text))

(defun init-markdown--math-overlay-near-p (beg end)
  "Return non-nil when a formula preview is near BEG through END."
  (let ((from (save-excursion
                (goto-char (max (point-min) (1- beg)))
                (line-beginning-position 0)))
        (to (save-excursion
              (goto-char (min (point-max) (1+ end)))
              (line-beginning-position 3))))
    (seq-some (lambda (overlay)
                (eq (overlay-get overlay 'category) 'mathjax))
              (overlays-in from to))))

(defun init-markdown--math-overlay-at-change-p (beg end)
  "Return non-nil when BEG through END directly touches a formula preview."
  (seq-some (lambda (overlay)
              (eq (overlay-get overlay 'category) 'mathjax))
            (overlays-in (max (point-min) (1- beg))
                         (min (point-max) (max (1+ beg) end)))))

(defun init-markdown--math-neighbor-change-p (text beg end &optional before)
  "Return non-nil when TEXT changes a boundary near math at BEG through END."
  (and (or (string-match-p ">" text)
           (and before (string-match-p "\n" text)))
       (init-markdown--math-overlay-near-p beg end)))

(defun init-markdown--math-closer-at (end)
  "Return a closing math delimiter immediately before END, if any."
  (cond
   ((and (>= end (+ (point-min) 2))
         (member (buffer-substring-no-properties (- end 2) end)
                 '("\\]" "\\)" "$$")))
    (buffer-substring-no-properties (- end 2) end))
   ((and (> end (point-min))
         (eq (char-before end) ?$)
         (not (eq (char-before (1- end)) ?$)))
    "$")))

(defun init-markdown--remember-new-math-closer (end)
  "Remember a just-typed formula closer ending at END."
  (when (init-markdown--math-closer-at end)
    (when (markerp init-markdown--math-fast-marker)
      (set-marker init-markdown--math-fast-marker nil))
    (setq init-markdown--math-fast-marker (copy-marker end))))

(defun init-markdown--heading-syntax-near-p (beg end)
  "Check changed ATX lines and neighboring Setext boundaries at BEG to END."
  (save-excursion
    (goto-char beg)
    (let ((from (line-beginning-position))
          (neighbor-from (line-beginning-position 0)))
      (goto-char end)
      (let ((to (line-beginning-position 2))
            (neighbor-to (line-beginning-position 3)))
        (goto-char from)
        (or (re-search-forward
             "^[ \t]*#\\{1,6\\}\\(?:[ \t]\\|$\\)" to t)
            (progn
              (goto-char neighbor-from)
              (re-search-forward "^[ \t]*\\(?:=+\\|-+\\)[ \t]*$"
                                 neighbor-to t)))))))

(defun init-markdown--note-math-before-change (beg end)
  "Record whether the old source near BEG through END affects rendering."
  (setq init-markdown--fence-edit-before
        (string-match-p (rx (any "`" "~"))
                        (buffer-substring-no-properties beg end)))
  ;; Prepare edited formulas while their source is revealed, including edits
  ;; to the body that do not retype the closing delimiter.
  (when-let* ((preview
               (seq-find (lambda (ov)
                           (overlay-get ov 'markdown-ts-appear-math--source))
                         (overlays-in beg (min (point-max) (max end (1+ beg)))))))
    (when (markerp init-markdown--math-fast-marker)
      (set-marker init-markdown--math-fast-marker nil))
    (setq init-markdown--math-fast-marker (copy-marker (overlay-end preview))))
  (setq init-markdown--math-edit-before
        (or (init-markdown--math-syntax-p
             (buffer-substring-no-properties beg end))
            (init-markdown--math-overlay-at-change-p beg end)
            (init-markdown--math-neighbor-change-p
             (buffer-substring-no-properties beg end) beg end t))
        init-markdown--heading-edit-before
        (init-markdown--heading-syntax-near-p beg end)))

(defun init-markdown--after-change-locally (_original beg end old-length)
  "Invalidate edited lines; rescan math only for math-relevant changes."
  (let* ((inserted (buffer-substring-no-properties beg end))
         (just-closed (and (< beg end)
                           (init-markdown--math-closer-at end)))
         (math-relevant
          (or init-markdown--math-edit-before
              just-closed
              (init-markdown--math-syntax-p inserted)
              (init-markdown--math-neighbor-change-p inserted beg end))))
    (pcase-let ((`(,refresh-beg . ,refresh-end)
                 (init-markdown--local-change-bounds beg end)))
      (init-markdown--delete-icon-overlays refresh-beg refresh-end)
      (if (or init-markdown--fence-edit-before
              (string-match-p (rx (any "`" "~")) inserted))
          (progn
            (setq init-markdown--heading-numbers-dirty t)
            (font-lock-flush refresh-beg (point-max)))
        (font-lock-flush refresh-beg refresh-end)))
    (if math-relevant
        (setq init-markdown--render-dirty t)
      ;; The package's before-change hook invalidates this tick even when no
      ;; formula was touched.  Overlay anchors already track ordinary edits.
      (setq markdown-ts-appear-math--scan-tick
            (buffer-chars-modified-tick)))
    (setq init-markdown--plain-edit-tick
          (and (zerop old-length)
               (< beg end)
               (not math-relevant)
               (not init-markdown--heading-edit-before)
               (string-match-p (rx bos (+ alnum) eos) inserted)
               (buffer-chars-modified-tick))
          init-markdown--plain-edit-end
          (and init-markdown--plain-edit-tick end)
          init-markdown--math-edit-before nil
          init-markdown--fence-edit-before nil
          init-markdown--heading-edit-before nil)
    (when just-closed
      (init-markdown--remember-new-math-closer end))))

(defun init-markdown--plain-edit-at-point-p ()
  "Return non-nil while processing a plain insertion at point."
  (and (equal init-markdown--plain-edit-tick
              (buffer-chars-modified-tick))
       (equal init-markdown--plain-edit-end (point))))

(defun init-markdown--skip-plain-edit-point-update (original)
  "Skip ORIGINAL when typing a word cannot change rendered element bounds."
  (unless (and (init-markdown--plain-edit-at-point-p)
               (null markdown-ts-appear--region))
    (funcall original)))

(defun init-markdown--skip-plain-edit-table-check (original)
  "Skip ORIGINAL when a plain edit cannot enter a Markdown table."
  (unless (and (init-markdown--plain-edit-at-point-p)
               (or (bound-and-true-p markdown-ts-in-table-mode)
                   (save-excursion
                     (let ((from (line-beginning-position 0))
                           (to (line-beginning-position 3)))
                       (goto-char from)
                       (not (search-forward "|" to t))))))
    (funcall original)))

(defun init-markdown--pending-math-p ()
  "Return non-nil when an eligible formula awaits a MathJax request."
  (seq-some (lambda (preview)
              (and (overlay-buffer preview)
                   (overlay-get preview 'markdown-ts-appear-math--input)
                   (markdown-ts-appear-math--eligible-p
                    (overlay-start preview) (overlay-end preview))))
            markdown-ts-appear-math--objects))

(defun init-markdown--request-math-in-batches
    (original preview math display-p)
  "Call ORIGINAL while the current request budget has room.
Keep PREVIEW's input for the next idle batch when the budget is exhausted."
  (if (or (null init-markdown--math-request-budget)
          (> init-markdown--math-request-budget 0))
      (progn
        (when init-markdown--math-request-budget
          (setq init-markdown--math-request-budget
                (1- init-markdown--math-request-budget)))
        (funcall original preview math display-p))
    (overlay-put preview 'markdown-ts-appear-math--input
                 (list math display-p))))

(defun init-markdown--schedule-math-prewarm ()
  "Arrange another idle batch when formulas still need MathJax."
  (when (and init-markdown--selective-rendering
             (init-markdown--pending-math-p)
             (not (timerp init-markdown--math-prewarm-timer)))
    (setq init-markdown--math-prewarm-timer
          (run-with-idle-timer init-markdown-math-prewarm-delay nil
                               #'init-markdown--run-math-prewarm
                               (current-buffer)))))

(defun init-markdown--schedule-fast-math ()
  "Prioritize a newly closed formula without waiting for the full rescan."
  (when (and (markerp init-markdown--math-fast-marker)
             (marker-buffer init-markdown--math-fast-marker)
             init-markdown--selective-rendering
             (not (timerp init-markdown--math-fast-timer)))
    (setq init-markdown--math-fast-timer
          (run-with-idle-timer init-markdown-math-fast-delay nil
                               #'init-markdown--run-fast-math
                               (current-buffer)))))

(defun init-markdown--run-fast-math (buffer)
  "Render the just-closed formula in BUFFER before background prewarming."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq init-markdown--math-fast-timer nil)
      (when (and (derived-mode-p 'markdown-ts-mode)
                 init-markdown--selective-rendering
                 (markerp init-markdown--math-fast-marker)
                 (marker-buffer init-markdown--math-fast-marker))
        (let* ((end (marker-position init-markdown--math-fast-marker))
               (candidate (init-markdown--fast-math-candidate-at end)))
          (if (not candidate)
              (progn
                (set-marker init-markdown--math-fast-marker nil)
                (setq init-markdown--math-fast-marker nil))
            (pcase-let ((`(,beg ,finish ,math ,display-p ,compatibility-p)
                         candidate))
              (let* ((source (buffer-substring-no-properties beg finish))
                     (preview (or (init-markdown--math-preview-at
                                   beg finish source)
                                  (let ((overlay
                                         (make-overlay beg finish nil t nil)))
                                    (overlay-put overlay 'category 'mathjax)
                                    (overlay-put overlay 'evaporate t)
                                    (overlay-put overlay
                                                 'init-markdown-latex-delimiter-math
                                                 compatibility-p)
                                    (overlay-put overlay
                                                 'markdown-ts-appear-math--source
                                                 source)
                                    (overlay-put overlay
                                                 'markdown-ts-appear-math--input
                                                 (list math display-p))
                                    (push overlay markdown-ts-appear-math--objects)
                                    overlay))))
                (when (and markdown-ts-appear-enable-math-preview
                           (markdown-ts-appear--active-p))
                  (markdown-ts-appear-math--display preview)
                  (when-let* ((input (overlay-get
                                      preview 'markdown-ts-appear-math--input)))
                    (overlay-put preview 'markdown-ts-appear-math--input nil)
                    (let ((init-markdown--math-request-budget nil))
                      (apply #'markdown-ts-appear-math--request
                             preview input)))
                  (set-marker init-markdown--math-fast-marker nil)
                  (setq init-markdown--math-fast-marker nil))))))))))

(defun init-markdown--run-math-prewarm (buffer)
  "Render the next batch of pending formulas in Markdown BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq init-markdown--math-prewarm-timer nil)
      (when (and (derived-mode-p 'markdown-ts-mode)
                 init-markdown--selective-rendering
                 (not init-markdown--render-dirty))
        ;; The preceding refresh has already reconciled source and overlays.
        ;; Send only pending requests here, avoiding a full-buffer scan per batch.
        (let ((init-markdown--math-request-budget
               init-markdown-math-prewarm-batch-size))
          (dolist (preview markdown-ts-appear-math--objects)
            (when (and (> init-markdown--math-request-budget 0)
                       (overlay-buffer preview)
                       (markdown-ts-appear-math--eligible-p
                        (overlay-start preview) (overlay-end preview)))
              (when-let* ((input (overlay-get preview
                                              'markdown-ts-appear-math--input)))
                (overlay-put preview 'markdown-ts-appear-math--input nil)
                (apply #'markdown-ts-appear-math--request preview input)))))
        (init-markdown--schedule-math-prewarm)))))

(defun init-markdown--defer-dirty-math-refresh (original &optional force)
  "Debounce changed-buffer scans and batch MathJax requests by ORIGINAL."
  (unless (and (not force)
               (or init-markdown--render-dirty
                   (init-markdown--plain-edit-at-point-p)))
    (let ((init-markdown--math-request-budget
           init-markdown-math-prewarm-batch-size))
      (funcall original force))))

(defun init-markdown--run-deferred-render (buffer)
  "Reconcile formula previews in live Markdown BUFFER."
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
                     init-markdown--selective-rendering)
            (markdown-ts-appear-math--refresh t))
          (when refresh-headings
            (init-markdown--refresh-heading-numbers buffer))
          (init-markdown--schedule-math-prewarm))))))

(defun init-markdown--pause-render-before-command ()
  "Keep background Markdown timers out of active command hooks."
  (when (timerp init-markdown--render-timer)
    (cancel-timer init-markdown--render-timer))
  (when (timerp init-markdown--math-prewarm-timer)
    (cancel-timer init-markdown--math-prewarm-timer))
  (when (timerp init-markdown--math-fast-timer)
    (cancel-timer init-markdown--math-fast-timer))
  (setq init-markdown--render-timer nil
        init-markdown--math-prewarm-timer nil
        init-markdown--math-fast-timer nil))

(defun init-markdown--schedule-deferred-render (&rest _)
  "Debounce a dirty preview update after command processing."
  (when (or init-markdown--render-dirty
            init-markdown--heading-numbers-dirty)
    (when (timerp init-markdown--render-timer)
      (cancel-timer init-markdown--render-timer))
    (setq init-markdown--render-timer
          (run-with-idle-timer init-markdown-render-debounce nil
                               #'init-markdown--run-deferred-render
                               (current-buffer))))
  (unless (or init-markdown--render-dirty
              init-markdown--heading-numbers-dirty)
    (init-markdown--schedule-math-prewarm))
  (init-markdown--schedule-fast-math)
  (setq init-markdown--plain-edit-tick nil
        init-markdown--plain-edit-end nil))

(defun init-markdown--cancel-deferred-render ()
  "Cancel pending preview and MathJax batch timers in this buffer."
  (when (timerp init-markdown--render-timer)
    (cancel-timer init-markdown--render-timer))
  (when (timerp init-markdown--math-prewarm-timer)
    (cancel-timer init-markdown--math-prewarm-timer))
  (when (timerp init-markdown--math-fast-timer)
    (cancel-timer init-markdown--math-fast-timer))
  (when (markerp init-markdown--math-fast-marker)
    (set-marker init-markdown--math-fast-marker nil))
  (setq init-markdown--render-timer nil
        init-markdown--math-prewarm-timer nil
        init-markdown--math-fast-timer nil
        init-markdown--math-fast-marker nil
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

(defun init-markdown--closed-fence-end ()
  "Return the end of a matching fence from this line, or nil.
Opening and closing fences must use the same character and quote depth;
the closer must be at least as long and contain no trailing info string."
  (save-excursion
    (beginning-of-line)
    (when (looking-at
           "[ \t]*\\(\\(?:>[ \t]?\\)*\\)[ \t]*\\(`\\{3,\\}\\|~\\{3,\\}\\)\\(.*\\)$")
      (let* ((quote-depth (cl-count ?> (match-string-no-properties 1)))
             (token (match-string-no-properties 2))
             (info (match-string-no-properties 3))
             (character (aref token 0))
             (length (length token)))
        (unless (and (eq character ?`) (string-search "`" info))
          (forward-line 1)
          (catch 'closed
            (while (re-search-forward
                    "^[ \t]*\\(\\(?:>[ \t]?\\)*\\)[ \t]*\\(`\\{3,\\}\\|~\\{3,\\}\\)[ \t]*$"
                    nil t)
              (let ((closing (match-string-no-properties 2)))
                (when (and (= quote-depth
                              (cl-count ?> (match-string-no-properties 1)))
                           (eq character (aref closing 0))
                           (>= (length closing) length))
                  (throw 'closed (min (point-max) (1+ (line-end-position)))))))))))))

(defun init-markdown--unclosed-fence-p (node)
  "Return non-nil when NODE belongs to a fence with no real closing token."
  (when-let* ((block (treesit-parent-until
                     node "\\`fenced_code_block\\'" t)))
    (< (length (treesit-filter-child
                block (lambda (child)
                        (and (equal (treesit-node-type child)
                                    "fenced_code_block_delimiter")
                             (not (treesit-node-check child 'missing))))))
       2)))

(defun init-markdown--pending-fence-language (node)
  "Interpret an unclosed fence NODE as ordinary Markdown."
  (when (init-markdown--unclosed-fence-p node)
    'markdown))

(defun init-markdown--closed-code-only (original node &rest args)
  "Call code renderer ORIGINAL only when NODE has a matching fence."
  (if (init-markdown--unclosed-fence-p node)
      ;; Deleting a closing fence leaves the host node alive, so the native
      ;; stale-overlay notifier does not remove its old code background.
      (when (equal (treesit-node-type node) "code_fence_content")
        (let ((beg (save-excursion
                     (goto-char (treesit-node-start node))
                     (line-beginning-position))))
          (dolist (ov (overlays-in beg (treesit-node-end node)))
            (when (and (overlay-get ov 'markdown-ts-code-block)
                       (= (overlay-start ov) beg))
              (delete-overlay ov)))))
    (apply original node args)))

(defvar-local init-markdown--pending-fence-settings nil)

(defun init-markdown--setup-pending-fences ()
  "Use a local Markdown parser for the body of an unfinished fence.
The primary parser retains its stable full-buffer range."
  (unless init-markdown--pending-fence-settings
    (setq init-markdown--pending-fence-settings
          (treesit-range-rules
           :embed #'init-markdown--pending-fence-language
           :host 'markdown :local t
           '((fenced_code_block (code_fence_content) @content) @language)))
    (setq-local treesit-range-settings
                (append init-markdown--pending-fence-settings
                        treesit-range-settings))))

(defun init-markdown--compute-math-source-ranges ()
  "Return source ranges delimited by LaTeX math markers in this buffer.
This scanner uses source text only; it never queries Tree-sitter from a timer
or edit hook."
  (let (ranges)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (cond
         ((and (bolp)
               (looking-at "[ \t]*\\(?:>[ \t]?\\)*[ \t]*\\(?:`\\{3,\\}\\|~\\{3,\\}\\)"))
          (if-let* ((end (init-markdown--closed-fence-end)))
              (goto-char end)
            (forward-line 1)))
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

(defvar-local init-markdown--interval-cache nil
  "Identity cache of immutable source range lists and their search vectors.")
(defvar-local init-markdown--interval-cache-tick nil)

(defun init-markdown--range-vector (ranges)
  "Return sorted, merged RANGES as a cached vector for binary searching."
  (unless (and init-markdown--interval-cache
               (equal init-markdown--interval-cache-tick
                      (buffer-chars-modified-tick)))
    (setq init-markdown--interval-cache (make-hash-table :test #'eq)
          init-markdown--interval-cache-tick (buffer-chars-modified-tick)))
  (or (gethash ranges init-markdown--interval-cache)
      (let (merged)
        (dolist (range (sort (copy-sequence ranges)
                            (lambda (a b) (< (car a) (car b)))))
          (if (and merged (<= (car range) (cdar merged)))
              (setcdr (car merged) (max (cdar merged) (cdr range)))
            (push (cons (car range) (cdr range)) merged)))
        (puthash ranges (vconcat (nreverse merged))
                 init-markdown--interval-cache))))

(defun init-markdown--range-overlaps-p (beg end ranges)
  "Return non-nil when BEG through END overlaps RANGES, in logarithmic time."
  (when (< beg end)
    (let* ((vector (init-markdown--range-vector ranges))
           (low 0) (high (length vector)))
      ;; Find the last interval starting strictly before END.
      (while (< low high)
        (let ((middle (/ (+ low high) 2)))
          (if (< (car (aref vector middle)) end)
              (setq low (1+ middle))
            (setq high middle))))
      (and (> low 0) (> (cdr (aref vector (1- low))) beg)))))

(defun init-markdown--position-in-ranges-p (position ranges)
  "Return non-nil when POSITION lies in one of RANGES."
  (init-markdown--range-overlaps-p position (1+ position) ranges))

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

(defun init-markdown--schedule-heading-numbers (&optional beg end _old-length)
  "Refresh section numbers when heading syntax changes near BEG through END."
  (when (or (null beg)
            init-markdown--heading-edit-before
            (init-markdown--heading-syntax-near-p beg end))
    (setq init-markdown--heading-numbers-dirty t)))

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
  (let (fence-ranges code-ranges)
    (save-excursion
      ;; Find fenced blocks first.  A closing fence must use the same character
      ;; and be at least as long as its opener.
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((line-beg (line-beginning-position))
              (line-end (line-end-position)))
          (if-let* (((not (init-markdown--range-overlaps-p
                          line-beg (max (1+ line-beg) line-end) math-ranges)))
                    (end (init-markdown--closed-fence-end)))
              (progn (push (cons line-beg end) fence-ranges)
                     (goto-char end))
            (forward-line 1))))
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

(defun init-markdown--fast-math-candidate-at (end)
  "Return a just-closed math segment ending at END, or nil.
The result is (BEG END MATH DISPLAY-P COMPATIBILITY-P).  This bounded,
source-only path avoids querying the live parser while an edit settles."
  (when-let* ((closing (init-markdown--math-closer-at end))
              (opening (pcase closing
                         ("\\]" "\\[")
                         ("\\)" "\\(")
                         (_ closing)))
              (close-beg (- end (length closing)))
              ((not (init-markdown--escaped-position-p close-beg))))
    (let ((lower (max (point-min)
                      (- end init-markdown-math-fast-max-chars))))
      (when (string= opening "$")
        (setq lower (max lower
                         (save-excursion
                           (goto-char close-beg)
                           (line-beginning-position)))))
      (save-excursion
        (goto-char close-beg)
        (catch 'found
          (while (search-backward opening lower t)
            (let ((beg (point)))
              (when (and (not (init-markdown--escaped-position-p beg))
                         (not (and (string= opening "$")
                                   (or (eq (char-before beg) ?$)
                                       (eq (char-after (1+ beg)) ?$))))
                         (or (not (string= opening "$"))
                             (and (> close-beg (1+ beg))
                                  (not (memq (char-after (1+ beg))
                                             '(?\s ?\t ?\n)))
                                  (not (memq (char-before close-beg)
                                             '(?\s ?\t ?\n)))))
                         (not (init-markdown--code-at-p beg)))
                (throw 'found
                       (list beg end
                             (init-markdown--normalize-quoted-math
                              (buffer-substring-no-properties
                               (+ beg (length opening)) close-beg)
                              beg)
                             (not (null (member opening '("\\[" "$$"))))
                             (not (string= opening "$"))))))))))))

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
            (and (eq init-markdown-render-mode 'live)
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
  "Enable only heading, math and table rendering in this buffer."
  (when (bound-and-true-p markdown-ts-appear-mode)
    (markdown-ts-appear-mode -1))
  (init-markdown--setup-table-inline-ranges)
  (init-markdown--enable-heading-numbers)
  (setq-local markdown-ts-inline-images nil)
  (markdown-ts--remove-image-overlays)
  (setq-local markdown-ts-hide-markup nil)
  (markdown-ts--set-hide-markup nil)
  ;; Only heading fontifiers set this property while native prose retains
  ;; `markdown-ts-hide-markup' nil.
  (add-to-invisibility-spec 'markdown-ts--markup)
  (when (require 'markdown-ts-appear nil t)
    (unless init-markdown--selective-rendering
      (setq init-markdown--selective-rendering t)
      ;; Reuse the table drawer and MathJax cache, never Appear's semantic
      ;; point tracking, general decorators, or global fontifier advice.
      (let ((markdown-ts-appear-code-fence-style 'raw)
            (markdown-ts-appear-block-quote-marker nil)
            (markdown-ts-appear-render-callouts nil))
        (markdown-ts-appear--install-block-font-lock))
      (add-hook 'after-change-functions #'init-markdown--selective-after-change 90 t)
      (add-hook 'post-command-hook #'init-markdown--selective-point-update nil t)
      (when markdown-ts-appear-enable-math-preview
        (markdown-ts-appear-math--setup)
        (remove-hook 'before-change-functions #'markdown-ts-appear-math--clear t)
        (add-hook 'before-change-functions #'init-markdown--clear-edited-math nil t))))
  (when (and (display-graphic-p) (require 'valign nil t))
    (unless valign-mode
      (valign-mode 1))))

(defun init-markdown--disable-renderers ()
  "Disable all display-only Markdown rendering in this buffer."
  (init-markdown--cancel-table-realign)
  (init-markdown--disable-heading-numbers)
  (when (bound-and-true-p markdown-ts-appear-mode)
    (markdown-ts-appear-mode -1))
  (when init-markdown--selective-rendering
    (setq init-markdown--selective-rendering nil)
    (remove-hook 'after-change-functions #'init-markdown--selective-after-change t)
    (remove-hook 'post-command-hook #'init-markdown--selective-point-update t)
    (remove-hook 'before-change-functions #'init-markdown--clear-edited-math t)
    (markdown-ts-appear-math--teardown)
    (markdown-ts-appear-stop)
    (markdown-ts-appear--remove-block-font-lock)
    (markdown-ts-appear--release-managed-properties))
  (init-markdown--cancel-deferred-render)
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
  (setq init-markdown-render-mode 'live)
  (init-markdown--enable-renderers)
  (init-markdown--selective-point-update)
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
  (setq init-markdown-render-mode 'preview)
  (init-markdown--enable-renderers)
  (init-markdown--selective-point-update)
  (markdown-ts-appear-math--refresh t)
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
  (init-markdown--configure-nonblocking-flyspell)
  (init-markdown--setup-pending-fences)
  (add-hook 'kill-buffer-hook #'init-markdown--cancel-table-realign nil t)
  (add-hook 'kill-buffer-hook #'init-markdown--disable-heading-numbers nil t)
  (add-hook 'kill-buffer-hook #'init-markdown--cancel-deferred-render nil t)
  (add-hook 'kill-buffer-hook #'init-markdown--dispose-selective-math nil t)
  (add-hook 'change-major-mode-hook #'init-markdown--dispose-selective-math nil t)
  (add-hook 'before-change-functions
            #'init-markdown--note-math-before-change -100 t)
  (add-hook 'pre-command-hook
            #'init-markdown--pause-render-before-command -100 t)
  (add-hook 'post-command-hook #'init-markdown--schedule-deferred-render 100 t)
  (remove-hook 'window-scroll-functions 'init-markdown--viewport-changed t)
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
  ;; Ordinary Markdown retains native source styling.  Only the three
  ;; selected renderers add display properties.
  (markdown-ts-hide-markup nil)
  (markdown-ts-inline-images nil)
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
  (markdown-ts-appear-link-icon "")
  (markdown-ts-appear-image-icon "")
  (markdown-ts-appear-code-fence-style 'raw)
  (markdown-ts-appear-render-callouts nil)
  (markdown-ts-appear-block-quote-marker nil)
  ;; Replace Markdown's ASCII pipes and delimiter row with box-drawing
  ;; characters while keeping the underlying source directly editable.
  (markdown-ts-appear-table-style 'unicode)
  :config
  (markdown-ts-appear--set-advice nil)
  (unless (advice-member-p #'init-markdown--selective-math-eligible
                           'markdown-ts-appear-math--eligible-p)
    (advice-add 'markdown-ts-appear-math--eligible-p :around
                #'init-markdown--selective-math-eligible))
  (unless (advice-member-p #'init-markdown--selective-active-p
                           'markdown-ts-appear--active-p)
    (advice-add 'markdown-ts-appear--active-p :before-until
                #'init-markdown--selective-active-p))
  (dolist (function '(markdown-ts--fontify-atx-heading
                      markdown-ts--fontify-atx-delimiter
                      markdown-ts--fontify-setext-heading))
    (unless (advice-member-p #'init-markdown--fontify-selected-heading function)
      (advice-add function :around #'init-markdown--fontify-selected-heading)))
  ;; Edits invalidate nearby lines.  Formula scans are debounced and MathJax
  ;; requests run in idle batches, so scrolling uses already rendered images.
  (dolist (function '(markdown-ts--fontify-code-block
                      markdown-ts--fontify-non-ts-code-block
                      markdown-ts--code-block-ts-language
                      markdown-ts--fontify-delimiter
                      markdown-ts-appear--fontify-code-block))
    (unless (advice-member-p #'init-markdown--closed-code-only function)
      (advice-add function :around #'init-markdown--closed-code-only
                  '((depth . -90)))))
  (unless (advice-member-p #'init-markdown--after-change-locally
                           'markdown-ts-appear--after-change)
    (advice-add 'markdown-ts-appear--after-change :around
                #'init-markdown--after-change-locally))
  (unless (advice-member-p #'init-markdown--skip-plain-edit-point-update
                           'markdown-ts-appear--update)
    (advice-add 'markdown-ts-appear--update :around
                #'init-markdown--skip-plain-edit-point-update))
  (unless (advice-member-p #'init-markdown--skip-plain-edit-table-check
                           'markdown-ts--enable-in-table-mode)
    (advice-add 'markdown-ts--enable-in-table-mode :around
                #'init-markdown--skip-plain-edit-table-check))
  (unless (advice-member-p #'init-markdown--defer-dirty-math-refresh
                           'markdown-ts-appear-math--refresh)
    (advice-add 'markdown-ts-appear-math--refresh :around
                #'init-markdown--defer-dirty-math-refresh))
  (when (advice-member-p 'init-markdown--limit-math-to-viewport
                         'markdown-ts-appear-math--eligible-p)
    (advice-remove 'markdown-ts-appear-math--eligible-p
                   'init-markdown--limit-math-to-viewport))
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
  ;; The budget advice must wrap the compatibility request as well: that
  ;; request sends directly to MathJax and does not call the package original.
  (when (advice-member-p #'init-markdown--request-math-in-batches
                         'markdown-ts-appear-math--request)
    (advice-remove 'markdown-ts-appear-math--request
                   #'init-markdown--request-math-in-batches))
  (advice-add 'markdown-ts-appear-math--request :around
              #'init-markdown--request-math-in-batches
              '((depth . -100)))
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
                  #'init-markdown--skip-link-fontification-in-latex-math)))
  ;; Repair buffers kept open across a configuration reload.
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'markdown-ts-mode)
        (init-markdown--configure-nonblocking-flyspell)
        (add-hook 'kill-buffer-hook #'init-markdown--dispose-selective-math nil t)
        (add-hook 'change-major-mode-hook #'init-markdown--dispose-selective-math nil t)
        (when (memq init-markdown-render-mode '(live preview))
          (init-markdown--enable-renderers))
        (init-markdown--setup-pending-fences)
        (setq init-markdown--source-index-tick nil
              init-markdown--heading-numbers-dirty t)
        (font-lock-flush)
        (remove-hook 'window-scroll-functions
                     'init-markdown--viewport-changed t)
        (init-markdown--cancel-deferred-render)
        (add-hook 'pre-command-hook
                  #'init-markdown--pause-render-before-command -100 t)
        (add-hook 'before-change-functions
                  #'init-markdown--note-math-before-change -100 t)
        (setq init-markdown--render-dirty t)
        (init-markdown--schedule-deferred-render)))))

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
