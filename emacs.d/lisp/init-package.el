;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)
(require 'package-vc)
(require 'cl-lib)
(require 'seq)

(setq package-user-dir (expand-file-name "elpa" user-emacs-directory))
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

;; Scanning the package descriptors is fast for this configuration and, unlike
;; a quickstart file left behind by an interrupted installation, cannot become
;; stale and cause already-installed packages to be installed repeatedly.
(setq package-quickstart nil)
(package-initialize)

;; `use-package' is built into Emacs 31.
(require 'use-package)

(setq use-package-always-ensure nil
      use-package-expand-minimally t)

(defconst my-core-packages
  '(doom-themes vertico orderless marginalia consult corfu cape consult-eglot
    yasnippet yasnippet-snippets yaml-mode magit diff-hl)
  "Third-party packages required by the main configuration.")

(defconst my-optional-packages
  '(embark embark-consult dired-subtree treemacs vterm helpful hl-todo
    rainbow-delimiters multiple-cursors zoxide consult-dir pet reformatter
    csv-mode cmake-mode auctex pdf-tools citar writegood-mode org-modern
    visual-fill-column mathjax minuet agent-shell
    ;; `avy' is not used on its own; helix-mode detects it with
    ;; `locate-library' and only then defines `gw' (goto word).
    helix avy)
  "Third-party packages that add optional features.")

(defconst my-config-packages
  (delete-dups (append my-core-packages my-optional-packages))
  "All third-party packages managed by this configuration.")

(defconst my-vc-packages
  '((embr . "https://github.com/emacs-os/embr.el")
    (markdown-ts-appear . "https://github.com/Thysrael/markdown-ts-appear"))
  "Packages installed from a Git checkout instead of a package archive.

This keeps packages that are unavailable from the configured archives, or
whose repository contents are needed at runtime, on their upstream heads.")

(defun my-install-packages ()
  "Install all missing packages and Tree-sitter grammars.

The command performs network access only when called interactively.  Its final
message reports counts maintained during this run instead of rescanning the
package database."
  (interactive)
  (let* ((pending (seq-filter (lambda (package)
                                (not (package-installed-p package)))
                              my-config-packages))
         (pending-vc (seq-filter (lambda (entry)
                                   (not (package-installed-p (car entry))))
                                 my-vc-packages))
         (declared (+ (length my-config-packages)
                      (length my-vc-packages)
                      (length init-treesit-languages)))
         (success-count (- (+ (length my-config-packages)
                              (length my-vc-packages))
                           (+ (length pending) (length pending-vc))))
         failed)
    (when pending
      (condition-case err
          (unless package-archive-contents
            (message "Refreshing package archives...")
            (redisplay)
            (package-refresh-contents))
        (error
         (setq failed
               (mapcar (lambda (package)
                         (cons package (error-message-string err)))
                       pending))
         ;; The archives are the only source for these, so skip them rather
         ;; than report the same failure once per package install attempt.
         (setq pending nil))))
    (cl-loop for package in pending
             for index from 1
             do (message "Installing package %d/%d: %s..."
                         index (length pending) package)
             do (redisplay)
             do (condition-case err
                    (progn
                      (package-install package)
                      (cl-incf success-count))
                  (error
                   (push (cons package (error-message-string err))
                         failed))))
    (cl-loop for (package . url) in pending-vc
             for index from 1
             do (message "Cloning package %d/%d: %s..."
                         index (length pending-vc) package)
             do (redisplay)
             do (condition-case err
                    (progn
                      (package-vc-install url)
                      (cl-incf success-count))
                  (error
                   (push (cons package (error-message-string err))
                         failed))))
    (setq failed
          (nconc failed (init-treesit-install-missing-grammars)))
    (cl-incf success-count
             (seq-count #'init-treesit-grammar-installed-p
                        init-treesit-languages))
    (if (null failed)
        (message "All configuration dependencies installed (%d success, 0 failed)."
                 success-count)
      (message "Dependency installation completed (%d success, %d failed): %s"
               success-count (length failed)
               (mapconcat (lambda (entry)
                            (format "%s (%s)" (car entry) (cdr entry)))
                          (nreverse failed) "; ")))))

(provide 'init-package)

;;; init-package.el ends here
