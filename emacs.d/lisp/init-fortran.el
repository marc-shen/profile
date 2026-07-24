;;; init-fortran.el --- Fortran development -*- lexical-binding: t; -*-

(use-package f90
  :ensure nil
  :mode (("\\.f90\\'" . f90-mode) ("\\.F90\\'" . f90-mode)
         ("\\.f95\\'" . f90-mode) ("\\.f03\\'" . f90-mode)
         ("\\.f08\\'" . f90-mode))
  :hook (f90-mode . (lambda () (my-eglot-ensure-if-available "fortls")))
  :custom
  (f90-do-indent 4)
  (f90-if-indent 4)
  (f90-type-indent 4)
  (f90-program-indent 2)
  (f90-continuation-indent 4))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(f90-mode . ("fortls"))))

(provide 'init-fortran)

;;; init-fortran.el ends here
