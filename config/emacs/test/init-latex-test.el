;;; init-latex-test.el --- LaTeX workflow regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'init-latex)
(require 'init-pdf)

(ert-deftest init-latex-default-survives-mode-initialization ()
  "AUCTeX must not reset the configured compiler to a single LaTeX pass."
  (with-temp-buffer
    (LaTeX-mode)
    (should (equal TeX-command-default "LaTeXMk"))
    (should (eq (lookup-key LaTeX-mode-map (kbd "C-c C-c"))
                #'TeX-command-master))))

(ert-deftest init-pdf-missing-output-does-not-create-broken-buffer ()
  "Viewing before compilation must not leave PDF Tools half initialized."
  (let* ((directory (make-temp-file "init-latex-test-" t))
         (pdf (expand-file-name "missing.pdf" directory)))
    (unwind-protect
        (cl-letf (((symbol-function 'TeX-active-master)
                   (lambda (&rest _) pdf)))
          (should-error (init-pdf-TeX-view) :type 'user-error)
          (should-not (find-buffer-visiting pdf)))
      (delete-directory directory))))

(ert-deftest init-pdf-existing-output-uses-synctex-viewer ()
  "The missing-file guard must retain AUCTeX's normal SyncTeX viewer."
  (let ((pdf (make-temp-file "init-latex-test-" nil ".pdf"))
        called)
    (unwind-protect
        (cl-letf (((symbol-function 'TeX-active-master)
                   (lambda (&rest _) pdf))
                  ((symbol-function 'TeX-pdf-tools-sync-view)
                   (lambda () (setq called t))))
          (init-pdf-TeX-view)
          (should called))
      (delete-file pdf))))

(ert-deftest init-latex-latexmk-success-selects-view ()
  "A no-op latexmk run succeeds even without a LaTeX output banner."
  (require 'tex)
  (let ((pdf (make-temp-file "init-latex-test-" nil ".pdf"))
        refreshed)
    (unwind-protect
        (with-temp-buffer
          (let ((TeX-command-buffer (current-buffer))
                (TeX-command-next "LaTeXMk")
                (TeX-after-compilation-finished-functions
                 (list (lambda (file) (setq refreshed file)))))
            (insert "Latexmk: All targets (sample701.pdf) are up-to-date\n")
            (cl-letf (((symbol-function 'process-status) (lambda (_) 'exit))
                      ((symbol-function 'process-exit-status) (lambda (_) 0))
                      ((symbol-function 'TeX-active-master) (lambda (&rest _) pdf)))
              (init-latex-latexmk-sentinel 'test "LaTeXMk")
              (should (equal TeX-command-next "View"))
              (should (equal refreshed pdf)))))
      (delete-file pdf))))

(ert-deftest init-latex-latexmk-failure-keeps-error-reporting ()
  "A failed build must not be treated as success because an old PDF exists."
  (let (reported)
    (cl-letf (((symbol-function 'process-status) (lambda (_) 'exit))
              ((symbol-function 'process-exit-status) (lambda (_) 12))
              ((symbol-function 'TeX-LaTeX-sentinel)
               (lambda (&rest _) (setq reported t))))
      (init-latex-latexmk-sentinel 'test "LaTeXMk")
      (should reported))))

;;; init-latex-test.el ends here
