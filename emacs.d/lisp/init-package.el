;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)

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
  '(which-key embark embark-consult dired-subtree treemacs helpful
    rainbow-delimiters pet reformatter jupyter csv-mode cmake-mode
    auctex pdf-tools citar writegood-mode org-modern))

(defun my-install-optional-packages ()
  "Install the optional packages declared by this configuration.

Run this interactively after reviewing the package list; it deliberately does
not perform network access during normal Emacs startup."
  (interactive)
  (unless package-archive-contents
    (package-refresh-contents))
  (dolist (package my-optional-packages)
    (unless (package-installed-p package)
      (package-install package)))
  (when package-quickstart
    (package-quickstart-refresh)))

(provide 'init-package)
