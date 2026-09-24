;;; init-markdown-test.el --- Markdown rendering regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'init-markdown)

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
      (should init-markdown--render-dirty)
      (should flushed)
      (should (< (- (cdr flushed) (car flushed)) (buffer-size)))
      (should (< (cdr flushed) (point-max))))))

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

(ert-deftest init-markdown-math-rendering-is-viewport-limited-and-debounced ()
  "Offscreen formulas and dirty-buffer scans wait for a viewport refresh."
  (cl-letf (((symbol-function 'init-markdown--viewport-ranges)
             (lambda () '((10 . 30)))))
    (should (init-markdown--limit-math-to-viewport
             (lambda (_beg _end) t) 15 20))
    (should-not (init-markdown--limit-math-to-viewport
                 (lambda (_beg _end) t) 31 40)))
  (let ((init-markdown--render-dirty t)
        (calls 0))
    (init-markdown--defer-dirty-math-refresh
     (lambda (&optional _force) (setq calls (1+ calls))))
    (should (= calls 0))
    (init-markdown--defer-dirty-math-refresh
     (lambda (&optional _force) (setq calls (1+ calls))) t)
    (should (= calls 1))))

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
