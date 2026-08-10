;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)
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
(unless package--initialized
  (package-initialize))

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

(setq use-package-always-ensure nil
      use-package-expand-minimally t)

(defconst my-core-packages
  '(doom-themes vertico orderless marginalia consult corfu cape consult-eglot
    yasnippet yasnippet-snippets magit diff-hl)
  "Third-party packages required by the main configuration.")

(defconst my-optional-packages
  '(which-key embark embark-consult dired-subtree treemacs vterm helpful hl-todo
    rainbow-delimiters multiple-cursors pet reformatter csv-mode cmake-mode
    auctex pdf-tools citar writegood-mode org-modern)
  "Third-party packages that add optional features.")

(defconst my-config-packages
  (delete-dups (append my-core-packages my-optional-packages))
  "All third-party packages managed by this configuration.")

(defun my-install-packages ()
  "Install all missing packages declared by this configuration.

The command performs network access only when called interactively.  Its final
message reports counts maintained during this run instead of rescanning the
package database."
  (interactive)
  (let* ((pending (seq-filter (lambda (package)
                                (not (package-installed-p package)))
                              my-config-packages))
         (success-count (- (length my-config-packages) (length pending)))
         failed)
    (if (null pending)
        (message "All packages installed (%d success, 0 failed)."
                 success-count)
      (condition-case err
          (unless package-archive-contents
            (message "Refreshing package archives...")
            (redisplay)
            (package-refresh-contents))
        (error
         (setq failed
               (mapcar (lambda (package)
                         (cons package (error-message-string err)))
                       pending))))
      (unless failed
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
                             failed)))))
      (if (null failed)
          (message "All packages installed (%d success, 0 failed)."
                   success-count)
        (message "Package installation completed (%d success, %d failed): %s"
                 success-count (length failed)
                 (mapconcat (lambda (entry)
                              (format "%s (%s)" (car entry) (cdr entry)))
                            (nreverse failed) "; "))))))

(provide 'init-package)

;;; init-package.el ends here
