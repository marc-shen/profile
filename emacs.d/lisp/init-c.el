;;; init-c.el --- C and C++ development -*- lexical-binding: t; -*-

(use-package cc-mode
  :ensure nil
  :hook ((c-mode . (lambda () (my-eglot-ensure-if-available "clangd")))
         (c++-mode . (lambda () (my-eglot-ensure-if-available "clangd")))
         (c-ts-mode . (lambda () (my-eglot-ensure-if-available "clangd")))
         (c++-ts-mode . (lambda () (my-eglot-ensure-if-available "clangd"))))
  :custom (c-default-style "linux") (c-basic-offset 4))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((c-mode c-ts-mode c++-mode c++-ts-mode)
                 . ("clangd" "--background-index" "--clang-tidy"
                    "--completion-style=detailed" "--header-insertion=never"))))

(use-package cmake-mode
  :if (package-installed-p 'cmake-mode)
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))

(provide 'init-c)

;;; init-c.el ends here
