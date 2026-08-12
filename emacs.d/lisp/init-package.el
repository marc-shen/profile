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
    rainbow-delimiters multiple-cursors zoxide consult-dir pet reformatter
    csv-mode cmake-mode auctex pdf-tools citar writegood-mode org-modern
    markdown-mode edit-indirect markdown-toc visual-fill-column texfrag)
  "Third-party packages that add optional features.")

(defconst my-config-packages
  (delete-dups (append my-core-packages my-optional-packages))
  "All third-party packages managed by this configuration.")

(defconst my-vc-packages
  '((embr . "https://github.com/emacs-os/embr.el"))
  "Packages installed from a Git checkout instead of a package archive.

`package-vc-install' clones the whole repository, which embr requires: it
looks for `embr.py' and `setup.sh' next to the `embr.el' it was loaded
from, and an archive built from the Lisp files alone would not carry them.")

(defun my-install-packages ()
  "Install all missing packages declared by this configuration.

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
         (declared (+ (length my-config-packages) (length my-vc-packages)))
         (success-count (- declared (+ (length pending) (length pending-vc))))
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
    (if (null failed)
        (message "All packages installed (%d success, 0 failed)."
                 success-count)
      (message "Package installation completed (%d success, %d failed): %s"
               success-count (length failed)
               (mapconcat (lambda (entry)
                            (format "%s (%s)" (car entry) (cdr entry)))
                          (nreverse failed) "; ")))))

(provide 'init-package)

;;; init-package.el ends here
