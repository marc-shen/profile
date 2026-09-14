;;; init-development.el --- General development tools -*- lexical-binding: t; -*-

;; Language servers, snippets, diagnostics, and the editing helpers that are
;; useful in any programming buffer.  Completion itself lives in
;; `init-completion', which is loaded first.

(require 'init-treesit)

(declare-function eglot-completion-at-point "eglot")
(declare-function pet-executable-find "pet" (executable &optional search-globally))

;; Emacs 31's Eglot recognizes the autoloaded `yas-minor-mode' and enables it
;; before expanding a server snippet.  Mode hooks keep snippets available away
;; from Eglot too, without loading Yasnippet during startup.
(use-package yasnippet
  :hook ((prog-mode . yas-minor-mode)
         (text-mode . yas-minor-mode)))
(use-package yasnippet-snippets :after yasnippet)

(use-package eglot
  :ensure nil
  :commands (eglot eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-confirm-server-initiated-edits nil)
  (eglot-events-buffer-size 0)
  (eglot-send-changes-idle-time 0.2)
  ;; `C-c s' for "server", not the `C-c l' that lsp-mode made conventional.
  ;; A prefix key shadows the single key of the same name for as long as the
  ;; mode is on, and `C-c l' is `windmove-right' -- one quarter of the
  ;; `C-c h/j/k/l' window movement set, which would then be missing in exactly
  ;; the buffers a language server runs in.
  :bind (:map eglot-mode-map
              ("C-c s a" . eglot-code-actions)
              ("C-c s r" . eglot-rename)
              ("C-c s f" . eglot-format-buffer)
              ("C-c s d" . eldoc-doc-buffer)
              ("C-c s q" . eglot-shutdown)))

;; Eglot's capf declares itself exclusive, which suppresses the Cape backends
;; whenever a server replies.  Making it non-exclusive lets keyword and dabbrev
;; completion fill the gaps the server leaves.
(with-eval-after-load 'eglot
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (when (require 'cape nil t)
                (setq-local completion-at-point-functions
                            (cons (cape-capf-nonexclusive #'eglot-completion-at-point)
                                  (remq #'eglot-completion-at-point
                                        completion-at-point-functions)))))))

;; Start language servers only after the corresponding Tree-sitter major mode
;; is active, and only when one of that language's supported servers exists.
(defconst init-eglot-server-executables
  '((python-mode "basedpyright-langserver" "pyright-langserver" "pylsp")
    (python-ts-mode "basedpyright-langserver" "pyright-langserver" "pylsp")
    (c-mode "clangd" "ccls")
    (c-ts-mode "clangd" "ccls")
    (c++-mode "clangd" "ccls")
    (c++-ts-mode "clangd" "ccls")
    (bash-ts-mode "bash-language-server")
    (json-ts-mode "vscode-json-language-server"
                  "vscode-json-languageserver" "json-languageserver")
    (yaml-ts-mode "yaml-language-server")
    (f90-mode "fortls")
    (fortran-mode "fortls"))
  "Language-server executables that permit automatic Eglot startup.")

(defun init-eglot--executable-find (executable)
  "Find EXECUTABLE, respecting Pet's project environment for Python."
  (if (and (memq major-mode '(python-mode python-ts-mode))
           (require 'pet nil t))
      (pet-executable-find executable)
    (executable-find executable)))

(defun init-eglot-ensure-if-available ()
  "Start Eglot when the current major mode has an installed server."
  (when (seq-some #'init-eglot--executable-find
                  (alist-get major-mode init-eglot-server-executables))
    (eglot-ensure)))

(dolist (mode '(python-mode python-ts-mode c-mode c-ts-mode c++-mode c++-ts-mode
                bash-ts-mode json-ts-mode yaml-ts-mode f90-mode fortran-mode))
  (add-hook (intern (format "%s-hook" mode))
            #'init-eglot-ensure-if-available))

(defconst init-development-tool-groups
  '(("Python LSP" "basedpyright-langserver" "pyright-langserver" "pylsp")
    ("Jupytext notebooks" "jupytext")
    ("C/C++ LSP" "clangd" "ccls")
    ("Bash LSP" "bash-language-server")
    ("JSON LSP" "vscode-json-language-server"
                "vscode-json-languageserver" "json-languageserver")
    ("YAML LSP" "yaml-language-server")
    ("Fortran LSP" "fortls")
    ("Fortran compiler" "gfortran" "ifx" "ifort" "nagfor")
    ("Tree-sitter C compiler" "cc" "gcc" "clang")
    ("Tree-sitter C++ compiler" "c++" "g++" "clang++")
    ("Grammar downloader" "git"))
  "External development tools checked by `my-development-environment-report'.")

(defun my-development-environment-report ()
  "Show whether this machine has the configured grammars and developer tools.

The report is read-only.  It is particularly useful after installing the
configuration on a second machine such as Fedora."
  (interactive)
  (let ((buffer (get-buffer-create "*Development environment*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Emacs %s on %s\n\n" emacs-version system-type)
                (format "Tree-sitter runtime: %s\n"
                        (if (treesit-available-p) "OK" "MISSING"))
                "\nGrammars:\n")
        (dolist (language init-treesit-languages)
          (insert (format "  %-16s %s\n" language
                          (if (init-treesit-grammar-installed-p language)
                              "OK" "MISSING"))))
        (insert "\nExternal tools (one executable per row is enough):\n")
        (pcase-dolist (`(,label . ,executables) init-development-tool-groups)
          (let ((found (seq-find #'executable-find executables)))
            (insert (format "  %-24s %s\n" label (or found "MISSING")))))
        (insert "\nMissing language servers are optional; their buffers still work "
                "without Eglot.\nRun M-x my-install-tree-sitter-grammars to "
                "install missing grammars.\n")
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buffer)))

(use-package consult-eglot
  :after (consult eglot)
  :bind (:map eglot-mode-map ("C-c s s" . consult-eglot-symbols)))

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)
              ("C-c ! p" . flymake-show-project-diagnostics))
  :custom (flymake-no-changes-timeout 0.5))

(use-package compile
  :ensure nil
  :custom
  (compilation-scroll-output 'first-error)
  (compilation-always-kill t)
  (compilation-ask-about-save nil))
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

(use-package helpful
  :if (package-installed-p 'helpful)
  :bind (([remap describe-function] . helpful-callable)
         ([remap describe-command] . helpful-command)
         ([remap describe-variable] . helpful-variable)
         ([remap describe-key] . helpful-key)))
(use-package rainbow-delimiters
  :if (package-installed-p 'rainbow-delimiters)
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package hl-todo
  :if (package-installed-p 'hl-todo)
  :hook (prog-mode . hl-todo-mode))

(use-package multiple-cursors
  :if (package-installed-p 'multiple-cursors)
  :custom
  ;; Per-command "run once or for every cursor" answers are local state.
  (mc/list-file (expand-file-name "mc-lists.el" init-var-directory))
  :bind (("C-c e l" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c e a" . mc/mark-all-like-this)
         ("C-c e r" . mc/mark-all-in-region)
         ("C-c e n" . mc/skip-to-next-like-this)
         ("C-c e p" . mc/skip-to-previous-like-this)
         ("C-c e u" . mc/unmark-next-like-this)
         ("C-c e SPC" . mc/vertical-align-with-space))
  :config
  ;; Corfu's popup only tracks the real cursor, and auto-completion fires on
  ;; every fake one.  Suspend it while several cursors are live.
  (add-hook 'multiple-cursors-mode-enabled-hook
            (lambda ()
              (setq-local corfu-auto nil)
              (when (fboundp 'corfu-quit) (corfu-quit))))
  (add-hook 'multiple-cursors-mode-disabled-hook
            (lambda () (kill-local-variable 'corfu-auto))))

(provide 'init-development)

;;; init-development.el ends here
