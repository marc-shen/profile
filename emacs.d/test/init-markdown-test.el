;;; init-markdown-test.el --- Markdown rendering regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'init-markdown)

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

(ert-deftest init-markdown-math-does-not-change-document-structure ()
  "Markdown-looking lines in math must not create or swallow body nodes."
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
    (let* ((root (treesit-buffer-root-node 'markdown))
           (headings (treesit-query-capture
                      root '(((atx_heading) @heading)
                             ((setext_heading) @heading))))
           (fences (treesit-query-capture
                    root '((fenced_code_block) @fence)))
           (lists (treesit-query-capture root '((list_item) @item)))
           (quotes (treesit-query-capture root '((block_quote) @quote)))
           (tables (treesit-query-capture root '((pipe_table) @table))))
      (should (equal (mapcar (lambda (capture)
                               (string-trim
                                (treesit-node-text (cdr capture) t)))
                             headings)
                     '("## Before" "## After" "### Real subsection")))
      (should-not fences)
      (should (= (length lists) 1))
      (should-not quotes)
      (should-not tables))
    (setq init-markdown-render-mode 'live)
    (init-markdown--refresh-heading-numbers (current-buffer))
    (should (equal (mapcar (lambda (overlay)
                             (overlay-get overlay 'before-string))
                           (reverse init-markdown--heading-number-overlays))
                   '("1  " "2  " "2.1  ")))))

(ert-deftest init-markdown-math-ranges-follow-edits ()
  "Editing math must keep later headings visible to the Markdown parser."
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
      (let ((headings
             (treesit-query-capture
              (treesit-buffer-root-node 'markdown)
              '((atx_heading) @heading))))
        (should (equal (mapcar (lambda (capture)
                                 (string-trim
                                  (treesit-node-text (cdr capture) t)))
                               headings)
                       '("## Before" "## After")))))))

(ert-deftest init-markdown-math-markers-in-code-are-not-formulas ()
  "Math-looking text in a code fence must not hide real Markdown headings."
  (skip-unless (treesit-ready-p 'markdown t))
  (with-temp-buffer
    (insert "```text\n\\[\n```\n\n## Real heading\n\n\\]\n")
    (markdown-ts-mode)
    (should-not (init-markdown--math-source-ranges))
    (should (equal (mapcar (lambda (capture)
                             (string-trim
                              (treesit-node-text (cdr capture) t)))
                           (treesit-query-capture
                            (treesit-buffer-root-node 'markdown)
                            '((atx_heading) @heading)))
                   '("## Real heading")))))

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
    (should (equal (mapcar (lambda (capture)
                             (string-trim
                              (treesit-node-text (cdr capture) t)))
                           (treesit-query-capture
                            (treesit-buffer-root-node 'markdown)
                            '((atx_heading) @heading)))
                   '("## Before" "## After")))))

;;; init-markdown-test.el ends here
