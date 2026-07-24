;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)
(require 'cl-lib)
(require 'seq)

(setq package-user-dir (expand-file-name "elpa" user-emacs-directory))
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

(setq package-quickstart t)
(unless package--initialized
  (package-initialize))

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

(setq use-package-always-ensure nil
      use-package-expand-minimally t)

(defconst my-optional-packages
  '(which-key embark embark-consult dired-subtree treemacs vterm helpful hl-todo
    rainbow-delimiters pet reformatter jupyter csv-mode cmake-mode
    auctex pdf-tools citar writegood-mode org-modern))

(defun my-install-optional-packages ()
  "Install the optional packages declared by this configuration.

Run this interactively after reviewing the package list; it deliberately does
not perform network access during normal Emacs startup."
  (interactive)
  (let ((pending (seq-filter (lambda (package)
                               (not (package-installed-p package)))
                             my-optional-packages))
        installed
        failed)
    (if (null pending)
        (message "All optional packages are already installed.")
      (unless package-archive-contents
        (message "Refreshing package archives...")
        (package-refresh-contents))
      (cl-loop for package in pending
               for index from 1
               do (message "Installing optional package %d/%d: %s..."
                           index (length pending) package)
               do (condition-case err
                      (progn
                        (package-install package)
                        (push package installed))
                    (error
                     (push (cons package (error-message-string err)) failed))))
      (when (and installed package-quickstart)
        (message "Refreshing package quickstart cache...")
        (package-quickstart-refresh))
      (if failed
          (message "Optional package installation finished with failures: %s"
                   (mapconcat (lambda (entry)
                                (format "%s (%s)" (car entry) (cdr entry)))
                              (nreverse failed) "; "))
        (message "Optional package installation finished: %s"
                 (mapconcat #'symbol-name (nreverse installed) ", "))))))

(provide 'init-package)
