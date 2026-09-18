;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)
(require 'package-vc)
(require 'cl-lib)
(require 'seq)
(require 'init-treesit)

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
    csv-mode code-cells cmake-mode auctex pdf-tools citar writegood-mode org-modern
    visual-fill-column valign mathjax minuet agent-shell msgpack
    ;; `avy' is not used on its own; helix-mode detects it with
    ;; `locate-library' and only then defines `gw' (goto word).
    helix avy)
  "Third-party packages that add optional features.")

(defconst my-config-packages
  (delete-dups (append my-core-packages my-optional-packages))
  "All third-party packages managed by this configuration.")

(defun my-missing-core-packages ()
  "Return core configuration packages that are not installed."
  (seq-filter (lambda (package)
                (not (package-installed-p package)))
              my-core-packages))

(defconst my-vc-packages
  '((embr . "https://github.com/emacs-os/embr.el")
    (markdown-ts-appear . "https://github.com/Thysrael/markdown-ts-appear")
    (tramp-rpc . "https://github.com/ArthurHeymans/emacs-tramp-rpc"))
  "Packages installed from a Git checkout instead of a package archive.

This keeps packages that are unavailable from the configured archives, or
whose repository contents are needed at runtime, on their upstream heads.")

(defvar pdf-info-epdfinfo-program)
(defvar vterm-always-compile-module)
(declare-function pdf-info-check-epdfinfo "pdf-info" (&optional interactive-p))
(declare-function pdf-tools-install "pdf-tools"
                  (&optional no-query-p skip-dependencies-p
                             no-error-p force-dependencies-p))

(defun my-install-pdf-tools-server ()
  "Build and verify the PDF Tools epdfinfo server when necessary."
  (unless (package-installed-p 'pdf-tools)
    (error "The pdf-tools package is not installed"))
  (require 'pdf-tools)
  ;; `pdf-tools-install' starts an asynchronous compilation when epdfinfo is
  ;; absent.  Wait here so `my-install-packages' can report the real outcome
  ;; instead of claiming success while the compiler is still running.
  (let ((result (pdf-tools-install t)))
    (when (bufferp result)
      (when-let* ((process (get-buffer-process result)))
        (while (process-live-p process)
          (accept-process-output process 0.2)))))
  (pdf-info-check-epdfinfo)
  t)

(defun my-install-vterm-module ()
  "Build and load vterm's native module when necessary."
  (unless (package-installed-p 'vterm)
    (error "The vterm package is not installed"))
  (unless module-file-suffix
    (error "This Emacs was built without dynamic module support"))
  (unless (require 'vterm-module nil t)
    ;; Loading vterm performs its synchronous CMake build.  Suppress its
    ;; confirmation question because this command is already explicitly an
    ;; installation command.
    (let ((vterm-always-compile-module t))
      (require 'vterm)))
  (unless (featurep 'vterm-module)
    (error "The vterm native module did not load after compilation"))
  t)

(defconst my-package-builders
  '((pdf-tools-build pdf-tools my-install-pdf-tools-server)
    (vterm-module-build vterm my-install-vterm-module))
  "Native build steps run by `my-install-packages'.

Each entry is (TASK PACKAGE FUNCTION).  FUNCTION is run only when PACKAGE was
installed successfully, so an archive failure is not reported a second time as
a build failure.")

(defun my-install-packages ()
  "Install packages and build their native components and grammars.

Network access occurs only while a package or grammar is missing.  Its final
message reports counts maintained during this run instead of rescanning the
package database."
  (interactive)
  (let* ((pending (seq-filter (lambda (package)
                                (not (package-installed-p package)))
                              my-config-packages))
         (pending-vc (seq-filter (lambda (entry)
                                   (not (package-installed-p (car entry))))
                                 my-vc-packages))
         (success-count (- (+ (length my-config-packages)
                              (length my-vc-packages))
                           (+ (length pending) (length pending-vc))))
         failed)
    (when pending
      (condition-case err
          ;; A non-nil archive cache can still name a package tarball that the
          ;; rolling archive has already replaced.  Refresh whenever something
          ;; is actually missing; this command is interactive and installations
          ;; are rare, so correctness matters more than saving this request.
          (progn
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
                      ;; Pass the configured name explicitly.  Repository
                      ;; names do not always match their Emacs package names
                      ;; (for example emacs-tramp-rpc -> tramp-rpc).
                      (package-vc-install url nil nil package)
                      (cl-incf success-count))
                  (error
                   (push (cons package (error-message-string err))
                         failed))))
    (cl-loop for (task package function) in my-package-builders
             when (package-installed-p package)
             do (message "Building native dependency: %s..." task)
             do (redisplay)
             do (condition-case err
                    (progn
                      (funcall function)
                      (cl-incf success-count))
                  (error
                   (push (cons task (error-message-string err)) failed))))
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
