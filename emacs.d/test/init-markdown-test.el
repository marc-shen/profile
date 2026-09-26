;;; init-markdown-test.el --- Markdown rendering regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'init-markdown)

(ert-deftest init-markdown-selective-rendering-leaves-prose-native ()
  "Only tables and headings decorate text; general Appear tracking is absent."
  (with-temp-buffer
    (insert "## Heading\n\n> quote **bold** [link](https://example.com)\n\n| A | B |\n|---|---|\n| x | y |\n\nEnd\n")
    (markdown-ts-mode)
    (goto-char (point-max))
    (font-lock-ensure)
    (should-not markdown-ts-appear-mode)
    (should-not (memq #'markdown-ts-appear--update post-command-hook))
    (should-not (memq #'markdown-ts-appear--after-change after-change-functions))
    (should init-markdown--selective-rendering)
    (should (invisible-p (point-min)))
    (goto-char (+ (point-min) 4))
    (init-markdown--selective-point-update)
    (font-lock-ensure)
    (should-not (invisible-p (point-min)))
    (goto-char (point-min))
    (search-forward ">")
    (should-not (get-text-property (1- (point)) 'display))
    (search-forward "**")
    (should-not (get-text-property (1- (point)) 'invisible))
    (search-forward "| A")
    (should (equal (get-text-property (- (point) 3) 'display) "│"))
    (my-markdown-render-source)
    (should-not init-markdown--selective-rendering)
    (should-not (memq #'init-markdown--selective-after-change after-change-functions))
    (my-markdown-render-live)
    (should-not markdown-ts-appear-mode)))

(ert-deftest init-markdown-selective-formula-reveals-on-entry ()
  "Cached formulas reveal source at point without semantic structure tracking."
  (with-temp-buffer
    (insert "Before\n\\[x+y\\]\nAfter\n")
    (markdown-ts-mode)
    (init-markdown--run-deferred-render (current-buffer))
    (let ((preview (car markdown-ts-appear-math--objects)))
      (should preview)
      (overlay-put preview 'markdown-ts-appear-math--image "rendered")
      (goto-char (+ (overlay-start preview) 3))
      (init-markdown--selective-point-update)
      (markdown-ts-appear-math--refresh t)
      (should-not (overlay-get preview 'display))
      (goto-char (point-max))
      (init-markdown--selective-point-update)
      (markdown-ts-appear-math--refresh t)
      (should (equal (overlay-get preview 'display) "rendered")))))

(ert-deftest init-markdown-fences-render-only-after-closing ()
  "Incomplete fences preserve following headings, emphasis, and formulas."
  (skip-unless (treesit-ready-p 'markdown t))
  (dolist (fence '("```python" "~~~python" "> ```python"))
    (with-temp-buffer
      (let* ((quoted (string-prefix-p ">" fence))
             (prefix (if quoted "> " ""))
             (closing (concat prefix (if (string-prefix-p "~" fence) "~~~" "```") "\n")))
        (insert fence "\n" prefix "\n" prefix "## Tail\n"
                prefix "\n" prefix "**bold**\n" prefix "\n"
                prefix "\\[x\\]\n")
        (markdown-ts-mode)
        (dotimes (_ 20)
          (font-lock-flush)
          (font-lock-ensure)
          (goto-char (point-min))
          (search-forward "Tail")
          (should-not (markdown-ts-at-code-block-p))
          (should (treesit-parent-until
                   (treesit-node-at (point) 'markdown) "\\`atx_heading\\'" t))
          (should (init-markdown--math-source-ranges))
          (goto-char (point-max))
          (let ((beg (point)))
            (insert closing)
            (font-lock-flush)
            (font-lock-ensure)
            (goto-char (point-min))
            (search-forward "Tail")
            (should (markdown-ts-at-code-block-p))
            (should-not (init-markdown--math-source-ranges))
            (delete-region beg (point-max))))
        (should-not (treesit-parser-included-ranges treesit-primary-parser))))))

(ert-deftest init-markdown-fence-closers-must-match ()
  "A short, wrong-character, or annotated fence cannot close a block."
  (dolist (tail '("```" "~~~~" "````python"))
    (with-temp-buffer
      (insert "````python\n## Tail\n" tail "\n")
      (goto-char (point-min))
      (should-not (init-markdown--closed-fence-end))))
  (with-temp-buffer
    (insert "````python\n## Tail\n`````\n")
    (goto-char (point-min))
    (should (= (init-markdown--closed-fence-end) (point-max)))))

(ert-deftest init-markdown-edited-formulas-prewarm-while-revealed ()
  "Editing either delimiter style prepares its image before point leaves."
  (skip-unless (treesit-ready-p 'markdown t))
  (dolist (source '("\\[x+y\\]" "$$x+y$$"))
    (with-temp-buffer
      (insert source)
      (markdown-ts-mode)
      (goto-char (point-max))
      (init-markdown--run-deferred-render (current-buffer))
      (goto-char (point-min))
      (search-forward "x")
      (insert "z")
      (should (markerp init-markdown--math-fast-marker))
      (let (requested)
        (cl-letf (((symbol-function 'markdown-ts-appear-math--request)
                   (lambda (_preview math display-p)
                     (setq requested (list math display-p)))))
          (init-markdown--run-fast-math (current-buffer)))
        (should (equal requested '("xz+y" t)))))))

(ert-deftest init-markdown-interval-index-preserves-range-boundaries ()
  "Indexed lookup agrees with a linear oracle for nested and unsorted ranges."
  (with-temp-buffer
    (let* ((ranges '((20 . 30) (3 . 8) (5 . 6) (8 . 12) (25 . 40)))
           (original (copy-tree ranges)))
      (dotimes (beg 45)
        (cl-loop for end from (1+ beg) to 46 do
                 (should
                  (eq (not (null (init-markdown--range-overlaps-p beg end ranges)))
                      (not (null
                            (seq-some (lambda (r)
                                        (and (< beg (cdr r)) (< (car r) end)))
                                      ranges)))))))
      (should (equal ranges original)))))

(ert-deftest init-markdown-blank-newline-between-structures-keeps-caches ()
  "A blank newline near a heading and formula needs no global reconciliation."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "## Heading\n\n\\[x\\]\n\nBody\n")
    (markdown-ts-mode)
    (init-markdown--run-deferred-render (current-buffer))
    (let ((formula (car markdown-ts-appear-math--objects))
          (headings init-markdown--heading-number-overlays))
      (goto-char (point-min))
      (forward-line 1)
      (markdown-ts-newline)
      (should-not init-markdown--render-dirty)
      (should-not init-markdown--heading-numbers-dirty)
      (should (memq formula markdown-ts-appear-math--objects))
      (should (eq headings init-markdown--heading-number-overlays)))))

(defun init-markdown-test--heading-texts ()
  "Return source heading text in the current test buffer."
  (mapcar (lambda (heading)
            (buffer-substring-no-properties (nth 1 heading) (nth 2 heading)))
          (init-markdown--source-headings)))

(ert-deftest init-markdown-heading-numbers-ignore-display-math ()
  "An equation's standalone equals sign must not reset heading numbering."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "## Previous section\n\n"
            "## Numerical Method and Error Framework\n\n"
            "### Overview of the EMPI Numerical Scheme\n\n"
            "\\[\n\\mathbf{X}_i\n=\n\\left(\\mathbf{r}_i\\right)\n\\]\n\n"
            "### Numerical Resolution and Sampling\n")
    (markdown-ts-mode)
    (setq init-markdown-render-mode 'live)
    (init-markdown--refresh-heading-numbers (current-buffer))
    (should (equal (mapcar (lambda (overlay)
                             (overlay-get overlay 'before-string))
                           (reverse init-markdown--heading-number-overlays))
                   '("1  " "2  " "2.1  " "2.2  ")))))

(ert-deftest init-markdown-heading-numbers-keep-real-setext-headings ()
  "A genuine Setext heading still changes the numbering hierarchy."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "## First section\n\n### Subsection\n\n"
            "Second section\n--------------\n\n"
            "### Another subsection\n")
    (markdown-ts-mode)
    (setq init-markdown-render-mode 'live)
    (init-markdown--refresh-heading-numbers (current-buffer))
    (should (equal (mapcar (lambda (overlay)
                             (overlay-get overlay 'before-string))
                           (reverse init-markdown--heading-number-overlays))
                   '("1  " "1.1  " "2  " "2.1  ")))))

(ert-deftest init-markdown-math-does-not-change-heading-structure ()
  "Markdown-looking lines in math must not affect source heading structure."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "## Before\n\n"
            "\\[\n"
            "### False heading\n"
            "=\n---\n- false list\n> false quote\n"
            "| a | b |\n|---|---|\n"
            "```\n"
            "\\]\n\n"
            "## After\n\n### Real subsection\n\n"
            "- real list item\n")
    (markdown-ts-mode)
    (should (equal (init-markdown-test--heading-texts)
                   '("Before" "After" "Real subsection")))
    (setq init-markdown-render-mode 'live)
    (init-markdown--refresh-heading-numbers (current-buffer))
    (should (equal (mapcar (lambda (overlay)
                             (overlay-get overlay 'before-string))
                           (reverse init-markdown--heading-number-overlays))
                   '("1  " "2  " "2.1  ")))))

(ert-deftest init-markdown-math-ranges-follow-edits ()
  "Editing math must keep later headings visible to the source scanner."
  (skip-unless (treesit-ready-p 'markdown t))
  (dolist (delimiters '(("\\[" . "\\]") ("$$" . "$$")
                       ("\\(" . "\\)")))
    (with-temp-buffer
      (insert "## Before\n\n"
              (car delimiters) "\n"
              "=\n"
              (cdr delimiters) "\n\n"
              "## After\n")
      (markdown-ts-mode)
      (goto-char (point-min))
      (search-forward "=\n")
      (insert "```\n### False heading\n")
      (should (equal (init-markdown-test--heading-texts)
                     '("Before" "After"))))))

(ert-deftest init-markdown-math-markers-in-code-are-not-formulas ()
  "Math-looking text in a code fence must not hide real Markdown headings."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "```text\n\\[\n```\n\n## Real heading\n\n\\]\n")
    (markdown-ts-mode)
    (should-not (init-markdown--math-source-ranges))
    (should (equal (init-markdown-test--heading-texts)
                   '("Real heading")))))

(ert-deftest init-markdown-multiple-math-blocks-cannot-hide-later-headings ()
  "A false fence in one formula must not hide later formulas or headings."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "## Before\n\n"
            "\\[\n```\n\\]\n\n"
            "\\[\n### False heading\n```\n\\]\n\n"
            "## After\n")
    (markdown-ts-mode)
    (should (= (length (init-markdown--math-source-ranges)) 2))
    (should (equal (init-markdown-test--heading-texts)
                   '("Before" "After")))))

(ert-deftest init-markdown-newline-keeps-full-parser-range ()
  "RET at EOF and in a quote must not install unstable parser ranges."
  (skip-unless (treesit-ready-p 'markdown t))
  (dolist (source '("final line" "> final quoted line"))
    (with-temp-buffer
      (insert source)
      (markdown-ts-mode)
      (goto-char (point-max))
      (markdown-ts-newline)
      (should-not (treesit-parser-included-ranges
                   (car (treesit-parser-list nil 'markdown))))
      ;; Our math and heading scans remain usable with every Tree-sitter query
      ;; disabled, which protects edit hooks and timers from native reentry.
      (cl-letf (((symbol-function 'treesit-node-at)
                 (lambda (&rest _) (ert-fail "Unexpected Tree-sitter query")))
                ((symbol-function 'treesit-buffer-root-node)
                 (lambda (&rest _) (ert-fail "Unexpected Tree-sitter query"))))
        (init-markdown--math-source-ranges)
        (init-markdown--source-headings))
      (when (string-prefix-p ">" source)
        (should (equal (buffer-substring-no-properties
                        (line-beginning-position) (point-max))
                       "> "))))))

(ert-deftest init-markdown-edit-invalidates-only-nearby-lines ()
  "An ordinary edit must not invalidate fontification for the whole buffer."
  (with-temp-buffer
    (insert "first\nsecond\nthird\nfourth\n")
    (goto-char (point-min))
    (forward-line 1)
    (let (flushed)
      (cl-letf (((symbol-function 'font-lock-flush)
                 (lambda (beg end &optional _buffer)
                   (setq flushed (cons beg end)))))
        (init-markdown--after-change-locally nil (point) (1+ (point)) 0))
      (should-not init-markdown--render-dirty)
      (should (equal markdown-ts-appear-math--scan-tick
                     (buffer-chars-modified-tick)))
      (should flushed)
      (should (< (- (cdr flushed) (car flushed)) (buffer-size)))
      (should (< (cdr flushed) (point-max))))))

(ert-deftest init-markdown-ordinary-newline-keeps-math-cache ()
  "An EOF newline keeps formulas cached; an edit inside math invalidates it."
  (with-temp-buffer
    (insert "Before\n\n$y$\n\nAfter\n")
    (let ((preview (make-overlay 9 12)))
      (overlay-put preview 'category 'mathjax)
      (goto-char (point-max))
      (init-markdown--note-math-before-change (point) (point))
      (let ((beg (point)))
        (insert "\n")
        (init-markdown--after-change-locally nil beg (point) 0))
      (should-not init-markdown--render-dirty)
      (should (equal markdown-ts-appear-math--scan-tick
                     (buffer-chars-modified-tick)))
      (goto-char 10)
      (init-markdown--note-math-before-change (point) (point))
      (let ((beg (point)))
        (insert "z")
        (init-markdown--after-change-locally nil beg (point) 0))
      (should init-markdown--render-dirty))))

(ert-deftest init-markdown-quote-prose-and-heading-edits-are-distinguished ()
  "Quote prose reuses caches, while creating a heading refreshes numbering."
  (with-temp-buffer
    (insert "> Plain paragraph\n\n")
    (goto-char (point-max))
    (init-markdown--note-math-before-change (point) (point))
    (let ((beg (point)))
      (insert "> More prose\n")
      (init-markdown--schedule-heading-numbers beg (point) 0)
      (init-markdown--after-change-locally nil beg (point) 0))
    (should-not init-markdown--render-dirty)
    (should-not init-markdown--heading-numbers-dirty)
    (init-markdown--note-math-before-change (point) (point))
    (let ((beg (point)))
      (insert "## New section\n")
      (init-markdown--schedule-heading-numbers beg (point) 0)
      (init-markdown--after-change-locally nil beg (point) 0))
    (should-not init-markdown--render-dirty)
    (should init-markdown--heading-numbers-dirty)))

(ert-deftest init-markdown-prose-next-to-math-keeps-preview-cache ()
  "Typing prose beside quoted math does not repeatedly scan formulas."
  (with-temp-buffer
    (insert "> prose\n> \\[x\\]\n")
    (let ((preview (make-overlay 11 16)))
      (overlay-put preview 'category 'mathjax)
      (goto-char 5)
      (init-markdown--note-math-before-change (point) (point))
      (let ((beg (point)))
        (insert "a")
        (init-markdown--after-change-locally nil beg (point) 0))
      (should-not init-markdown--render-dirty)
      (goto-char (point-min))
      (init-markdown--note-math-before-change (point) (point))
      (let ((beg (point)))
        (insert "> ")
        (init-markdown--after-change-locally nil beg (point) 0))
      (should init-markdown--render-dirty))))

(ert-deftest init-markdown-eof-newline-skips-live-formula-rescan ()
  "A real live buffer must not rescan formulas for a plain EOF newline."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "## Section\n\n$x$\n\nPlain text\n")
    (markdown-ts-mode)
    (init-markdown--run-deferred-render (current-buffer))
    (should (= (length markdown-ts-appear-math--objects) 1))
    (goto-char (point-max))
    (insert "\n")
    (should-not init-markdown--render-dirty)
    (should-not init-markdown--heading-numbers-dirty)
    (cl-letf (((symbol-function 'markdown-ts-appear-math--scan)
               (lambda () (ert-fail "Unexpected full formula scan"))))
      (markdown-ts-appear-math--refresh t))
    (should (= (length markdown-ts-appear-math--objects) 1))))

(ert-deftest init-markdown-flyspell-does-not-block-each-keystroke ()
  "Markdown checks edited words on departure rather than in every key hook."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (markdown-ts-mode)
    (when (bound-and-true-p flyspell-mode)
      (should flyspell-delay-use-timer)
      (should flyspell-check-changes)
      (should-not (memq #'flyspell-post-command-hook post-command-hook))
      (should (memq #'flyspell-check-changes post-command-hook)))))

(ert-deftest init-markdown-fast-math-finds-only-local-source-formulas ()
  "The fast path recognizes quoted math without accepting literal code."
  (with-temp-buffer
    (insert "> \\[\n> x + y\n> \\]\n")
    (goto-char (point-min))
    (search-forward "\\]")
    (pcase-let ((`(,beg ,end ,math ,display-p ,compatibility-p)
                 (init-markdown--fast-math-candidate-at (point))))
      (should (equal (buffer-substring-no-properties beg end)
                     "\\[\n> x + y\n> \\]"))
      (should (equal math "\nx + y\n"))
      (should display-p)
      (should compatibility-p)))
  (with-temp-buffer
    (insert "```text\n\\[x\\]\n```\n")
    (goto-char (point-min))
    (search-forward "\\]")
    (should-not (init-markdown--fast-math-candidate-at (point))))
  (with-temp-buffer
    (insert "Inline $x+y$")
    (should (equal (init-markdown--fast-math-candidate-at (point-max))
                   '(8 13 "x+y" nil nil))))
  (with-temp-buffer
    (insert "$$\nx+y\n$$")
    (should (equal (init-markdown--fast-math-candidate-at (point-max))
                   '(1 10 "\nx+y\n" t t)))))

(ert-deftest init-markdown-new-formula-renders-before-full-rescan ()
  "Closing a formula sends it directly to MathJax ahead of the idle queue."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "> \\[\n> x + y\n> \\")
    (markdown-ts-mode)
    (goto-char (point-max))
    (let (requested)
      (insert "]")
      (should (markerp init-markdown--math-fast-marker))
      (cl-letf (((symbol-function 'markdown-ts-appear-math--eligible-p)
                 (lambda (&rest _) t))
                ((symbol-function 'markdown-ts-appear-math--display)
                 (lambda (&rest _) nil))
                ((symbol-function 'markdown-ts-appear-math--request)
                 (lambda (_preview math display-p)
                   (setq requested (list math display-p)))))
        (init-markdown--run-fast-math (current-buffer)))
      (should (equal requested '("\nx + y\n" t)))
      (should (= (length markdown-ts-appear-math--objects) 1))
      (should-not init-markdown--math-fast-marker)
      (should init-markdown--render-dirty))))

(ert-deftest init-markdown-plain-typing-skips-redundant-point-query ()
  "A word insertion skips one query; moving or typing syntax does not."
  (with-temp-buffer
    (insert "> ordinary prose\n")
    (goto-char (line-end-position 0))
    (let ((beg (point)) (queries 0))
      (insert "文字")
      (init-markdown--after-change-locally nil beg (point) 0)
      (init-markdown--skip-plain-edit-point-update
       (lambda () (setq queries (1+ queries))))
      (should (= queries 0))
      (init-markdown--schedule-deferred-render)
      (init-markdown--skip-plain-edit-point-update
       (lambda () (setq queries (1+ queries))))
      (should (= queries 1))
      (let ((syntax-beg (point)))
        (insert "#")
        (init-markdown--after-change-locally nil syntax-beg (point) 0))
      (init-markdown--skip-plain-edit-point-update
       (lambda () (setq queries (1+ queries))))
      (should (= queries 2)))))

(ert-deftest init-markdown-plain-prose-skips-only-irrelevant-table-checks ()
  "Plain quote text skips table detection, but pipe syntax is checked."
  (with-temp-buffer
    (insert "> Plain prose\n")
    (goto-char (line-end-position 0))
    (let ((beg (point)) (checks 0))
      (insert "word")
      (init-markdown--after-change-locally nil beg (point) 0)
      (init-markdown--skip-plain-edit-table-check
       (lambda () (setq checks (1+ checks))))
      (should (= checks 0))
      (let ((markdown-ts-in-table-mode t))
        (init-markdown--skip-plain-edit-table-check
         (lambda () (setq checks (1+ checks)))))
      (should (= checks 0))
      (insert "|")
      (init-markdown--skip-plain-edit-table-check
       (lambda () (setq checks (1+ checks))))
      (should (= checks 1)))))

(ert-deftest init-markdown-source-index-is-shared-per-edit ()
  "Math, code, and heading consumers share one source index per edit."
  (with-temp-buffer
    (insert "## Before\n\n\\[ x = y \\]\n\n```text\n# code\n```\n")
    (let ((math-original
           (symbol-function 'init-markdown--compute-math-source-ranges))
          (code-original
           (symbol-function 'init-markdown--compute-code-source-ranges))
          (heading-original
           (symbol-function 'init-markdown--compute-source-headings))
          (math-count 0) (code-count 0) (heading-count 0))
      (cl-letf (((symbol-function 'init-markdown--compute-math-source-ranges)
                 (lambda () (setq math-count (1+ math-count))
                   (funcall math-original)))
                ((symbol-function 'init-markdown--compute-code-source-ranges)
                 (lambda (&optional ranges)
                   (setq code-count (1+ code-count))
                   (funcall code-original ranges)))
                ((symbol-function 'init-markdown--compute-source-headings)
                 (lambda () (setq heading-count (1+ heading-count))
                   (funcall heading-original))))
        (dotimes (_ 2)
          (init-markdown--math-source-ranges)
          (init-markdown--code-source-ranges)
          (init-markdown--source-headings)))
      (should (= math-count 1))
      (should (= code-count 1))
      (should (= heading-count 1)))))

(ert-deftest init-markdown-math-rendering-is-debounced-and-batched ()
  "Editing defers scans; each refresh sends a bounded number of requests."
  (let ((init-markdown--render-dirty t)
        (calls 0))
    (init-markdown--defer-dirty-math-refresh
     (lambda (&optional _force) (setq calls (1+ calls))))
    (should (= calls 0))
    (init-markdown--defer-dirty-math-refresh
     (lambda (&optional _force) (setq calls (1+ calls))) t)
    (should (= calls 1)))
  (with-temp-buffer
    (let* ((preview (make-overlay (point-min) (point-min)))
           (init-markdown--math-request-budget 1)
           (sent 0))
      (init-markdown--request-math-in-batches
       (lambda (&rest _) (setq sent (1+ sent))) preview "x" nil)
      (init-markdown--request-math-in-batches
       (lambda (&rest _) (setq sent (1+ sent))) preview "y" t)
      (should (= sent 1))
      (should (equal (overlay-get preview
                                  'markdown-ts-appear-math--input)
                     '("y" t))))))

(ert-deftest init-markdown-block-quote-display-math-strips-quote-prefixes ()
  "A quoted display formula sends clean TeX, while retaining source markers."
  (skip-unless (and (treesit-ready-p 'markdown t)
                    (locate-library "markdown-ts-appear")))
  (with-temp-buffer
    (insert "> \\[\n"
            "> \\mathbf X_{i+1}=\n"
            "> \\mathcal M^{\\rm num}_{h_i}(\\mathbf X_i).\n"
            "> \\]\n")
    (markdown-ts-mode)
    (init-markdown--scan-latex-delimiter-math (lambda () nil))
    (let* ((preview
            (seq-find
             (lambda (candidate)
               (overlay-get candidate 'init-markdown-latex-delimiter-math))
             markdown-ts-appear-math--objects))
           (input (car (overlay-get preview
                                    'markdown-ts-appear-math--input))))
      (should preview)
      (should (equal input
                     "\n\\mathbf X_{i+1}=\n\\mathcal M^{\\rm num}_{h_i}(\\mathbf X_i).\n"))
      (should (string-match-p
               (regexp-quote "\n> \\mathcal")
               (buffer-substring-no-properties
                (overlay-start preview) (overlay-end preview)))))))

;;; init-markdown-test.el ends here
