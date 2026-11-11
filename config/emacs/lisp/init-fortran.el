;;; init-fortran.el --- Fortran development -*- lexical-binding: t; -*-

(defvar cape-keyword-list)
(declare-function f90-ts-mode "f90-ts-mode")

(defface my-f90-ts-object-face
  '((((class color) (min-colors 89))
     (:foreground "#66D9EF" :weight semi-bold :slant italic))
    (t (:inherit font-lock-variable-use-face :weight bold :slant italic)))
  "Face for an object at the root of a Fortran component expression."
  :group 'f90-ts-font-lock)

(defface my-f90-ts-property-face
  '((((class color) (min-colors 89))
     (:foreground "#FD971F" :weight normal :slant normal))
    (t (:inherit font-lock-builtin-face :weight normal :slant normal)))
  "Face for a data component in a Fortran component expression."
  :group 'f90-ts-font-lock)

;; Keep the mature built-in mode as a dependency-free fallback.  Modern free
;; source form uses `f90-ts-mode' below once both its package and grammar exist.
(use-package f90
  :ensure nil
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

(use-package f90-ts-mode
  :defer t)

(defun my-f90-ts-append-component-font-lock (rules)
  "Add object and component highlighting to f90-ts font-lock RULES."
  (append rules
          (treesit-font-lock-rules
           :language 'fortran
           :feature 'variable
           '((derived_type_member_expression
              (identifier) @my-f90-ts-object-face)
             (type_member) @my-f90-ts-property-face))))

(with-eval-after-load 'f90-ts-mode
  ;; Upstream highlights SELF/THIS specially and type-bound procedure calls,
  ;; but currently leaves ordinary objects and data components unfontified.
  ;; Extend its Tree-sitter query before each buffer builds its font-lock rules.
  (set-face-attribute 'f90-ts-font-lock-special-var-face nil
                      :inherit 'my-f90-ts-object-face)
  (unless (advice-member-p #'my-f90-ts-append-component-font-lock
                           'f90-ts-font-lock-rules)
    (advice-add 'f90-ts-font-lock-rules :filter-return
                #'my-f90-ts-append-component-font-lock)))

(defun init-fortran-modern-mode ()
  "Use Tree-sitter for modern Fortran, falling back to `f90-mode'."
  (interactive)
  (if (and (init-treesit-grammar-installed-p 'fortran)
           (require 'f90-ts-mode nil t))
      (f90-ts-mode)
    (f90-mode)))

(add-to-list 'auto-mode-alist
             '("\\.\\(?:[fF]90\\|[fF]95\\|[fF]03\\|[fF]08\\|[fF]18\\)\\'"
               . init-fortran-modern-mode))

;; Include the common legacy and preprocessed fixed-form suffixes explicitly;
;; the stock auto-mode list only covers .f/.F and lower-case .for.
(use-package fortran
  :ensure nil)
(dolist (pattern '("\\.[fF]\\'" "\\.[fF][oO][rR]\\'"
                   "\\.[fF][tT][nN]\\'" "\\.[fF]77\\'"))
  (add-to-list 'auto-mode-alist (cons pattern 'fortran-mode)))

;; Cape ships keywords for `f90-mode' only; reuse them for the other Fortran
;; modes.  Eglot completion remains the primary semantic completion source.
(with-eval-after-load 'cape-keyword
  (dolist (mode '(f90-ts-mode fortran-mode))
    (unless (assq mode cape-keyword-list)
      (add-to-list 'cape-keyword-list
                   (cons mode (cdr (assq 'f90-mode cape-keyword-list)))))))

(provide 'init-fortran)

;;; init-fortran.el ends here
