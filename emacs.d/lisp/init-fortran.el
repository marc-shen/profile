;;; init-fortran.el --- Fortran development -*- lexical-binding: t; -*-

(defvar cape-keyword-list)

;; Emacs 31 does not provide a `fortran-ts-mode'.  Keep its mature built-in
;; modes: `f90-mode' for free source form and `fortran-mode' for fixed source
;; form.  Eglot 31 already maps both modes to fortls.
(use-package f90
  :ensure nil
  :mode ("\\.\\(?:[fF]90\\|[fF]95\\|[fF]03\\|[fF]08\\|[fF]18\\)\\'"
         . f90-mode)
  :custom
  (f90-do-indent 4)
  (f90-if-indent 4)
  (f90-type-indent 4)
  (f90-program-indent 2)
  (f90-continuation-indent 4)
  ;; Complete a bare END according to its matching block, without the old
  ;; cursor blink.  Do not rewrite the user's keyword capitalization.
  (f90-smart-end 'no-blink)
  (f90-auto-keyword-case nil))

;; Include the common legacy and preprocessed fixed-form suffixes explicitly;
;; the stock auto-mode list only covers .f/.F and lower-case .for.
(use-package fortran
  :ensure nil)
(dolist (pattern '("\\.[fF]\\'" "\\.[fF][oO][rR]\\'"
                   "\\.[fF][tT][nN]\\'" "\\.[fF]77\\'"))
  (add-to-list 'auto-mode-alist (cons pattern 'fortran-mode)))

;; Cape ships keywords for `f90-mode' only; reuse them for fixed-form Fortran.
(with-eval-after-load 'cape-keyword
  (unless (assq 'fortran-mode cape-keyword-list)
    (add-to-list 'cape-keyword-list
                 (cons 'fortran-mode (cdr (assq 'f90-mode cape-keyword-list))))))

(provide 'init-fortran)

;;; init-fortran.el ends here
