;;; init-treesit.el --- Tree-sitter languages for Emacs 31 -*- lexical-binding: t; -*-

(require 'treesit)

;; Requiring the built-in modes registers Emacs 31's pinned source recipes in
;; `treesit-language-source-alist'.  Keeping the recipes in Emacs itself avoids
;; duplicating upstream URLs and revisions in this configuration.
(require 'python)
(require 'c-ts-mode)
(require 'sh-script)
(require 'json-ts-mode)
(require 'yaml-ts-mode)
(require 'markdown-ts-mode)

(defconst init-treesit-languages
  '(python c cpp bash json yaml markdown markdown-inline)
  "Tree-sitter grammars installed by this configuration.")

(defconst init-treesit-major-mode-remaps
  '((python-mode python-ts-mode python)
    (c-mode c-ts-mode c)
    (c++-mode c++-ts-mode cpp)
    (js-json-mode json-ts-mode json)
    (json-mode json-ts-mode json)
    (yaml-mode yaml-ts-mode yaml))
  "Conventional mode, Tree-sitter mode, and required grammar triples.")

(defun init-treesit-refresh-major-mode-remaps ()
  "Enable configured remaps whose grammars are currently available.

Missing grammars deliberately leave the traditional mode in place.  This
makes a fresh installation usable before its grammars have been compiled."
  (pcase-dolist (`(,traditional ,tree-sitter ,language)
                 init-treesit-major-mode-remaps)
    (setq major-mode-remap-alist
          (assq-delete-all traditional major-mode-remap-alist))
    (when (init-treesit-grammar-installed-p language)
      (push (cons traditional tree-sitter) major-mode-remap-alist))))

;; `sh-mode' also handles Zsh and other shells, so do not remap it globally to
;; a Bash parser.  File names and shebangs that explicitly mean Bash opt in.
(defun init-treesit-bash-mode ()
  "Use `bash-ts-mode' when possible, otherwise traditional Bash mode."
  (if (init-treesit-grammar-installed-p 'bash)
      (bash-ts-mode)
    (sh-mode)
    (sh-set-shell "bash")))

(add-to-list 'auto-mode-alist
             '("\\.\\(?:bash\\|sh\\)\\'" . init-treesit-bash-mode))
(setf (alist-get "bash" interpreter-mode-alist nil nil #'string=)
      'init-treesit-bash-mode)

;; There is no built-in traditional YAML mode.  Prefer its TS mode, then the
;; optional yaml-mode package, with conf-mode as a dependency-free fallback.
(defun init-treesit-yaml-mode ()
  "Select the best available YAML major mode."
  (cond ((init-treesit-grammar-installed-p 'yaml) (yaml-ts-mode))
        ((fboundp 'yaml-mode) (yaml-mode))
        (t (conf-mode))))

(add-to-list 'auto-mode-alist
             '("\\.ya?ml\\'" . init-treesit-yaml-mode))

;; Use the richest built-in font-lock rules once the parsers are active.
(setq treesit-font-lock-level 4)

(defun init-treesit-grammar-installed-p (language)
  "Return non-nil when the grammar for LANGUAGE can be loaded."
  (treesit-language-available-p language))

(init-treesit-refresh-major-mode-remaps)

(defun init-treesit-install-missing-grammars ()
  "Install missing grammars and return an alist of failures.

Each failure has the form (LANGUAGE . MESSAGE).  Successful and already
installed grammars are omitted from the return value."
  (let (failed)
    (dolist (language init-treesit-languages)
      (unless (init-treesit-grammar-installed-p language)
        (message "Installing Tree-sitter grammar: %s..." language)
        (redisplay)
        (condition-case err
            (treesit-install-language-grammar language)
          (error
           (push (cons language (error-message-string err)) failed)))))
    (init-treesit-refresh-major-mode-remaps)
    (nreverse failed)))

(defun my-install-tree-sitter-grammars ()
  "Install every missing grammar used by this configuration."
  (interactive)
  (let ((failed (init-treesit-install-missing-grammars)))
    (if failed
        (message "Tree-sitter installation failed: %s"
                 (mapconcat (lambda (entry)
                              (format "%s (%s)" (car entry) (cdr entry)))
                            failed "; "))
      (message "All %d Tree-sitter grammars are installed."
               (length init-treesit-languages)))))

(provide 'init-treesit)

;;; init-treesit.el ends here
