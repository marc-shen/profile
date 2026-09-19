;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)
(require 'package-vc)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)
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
    visual-fill-column valign mathjax minuet agent-shell msgpack f90-ts-mode
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
(declare-function package--upgradeable-packages "package"
                  (&optional include-builtins))
(declare-function package-vc--checkout-dir "package-vc" (pkg-desc))

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

(defvar my-package--restart-timer nil
  "Timer used to restart Emacs after successful package maintenance.")

(defun my-package--result (success failures)
  "Build a package-maintenance result from SUCCESS and FAILURES."
  (list :success success :failures failures))

(defun my-package--merge-results (&rest results)
  "Combine package-maintenance RESULTS into one result."
  (my-package--result
   (apply #'+ (mapcar (lambda (result) (plist-get result :success)) results))
   (apply #'append
          (mapcar (lambda (result) (plist-get result :failures)) results))))

(defun my-package--format-summary (operation result)
  "Format the result of OPERATION from RESULT for display and logging."
  (let ((failures (plist-get result :failures)))
    (concat
     (format "%s\nTime: %s\nEmacs: %s\nSystem: %s\nSuccess: %d\nFailed: %d\n"
             operation
             (format-time-string "%Y-%m-%d %H:%M:%S %z")
             emacs-version
             system-configuration
             (plist-get result :success)
             (length failures))
     (when failures
       (concat
        "\nErrors:\n"
        (mapconcat (lambda (entry)
                     (format "- %s: %s" (car entry) (cdr entry)))
                   failures "\n")
        "\n")))))

(defun my-package--write-error-log (operation result)
  "Write failures from OPERATION and RESULT below ~/.emacs.d/log/.
Return the absolute log file name."
  (let* ((directory (expand-file-name "log" user-emacs-directory))
         (file (expand-file-name
                (format "package-errors-%s.log"
                        (format-time-string "%Y%m%d-%H%M%S"))
                directory)))
    (make-directory directory t)
    (write-region (my-package--format-summary operation result)
                  nil file nil 'silent)
    file))

(defun my-package--finish (operation result)
  "Report OPERATION using RESULT, logging failures or scheduling a restart."
  (let ((failures (plist-get result :failures)))
    (if failures
        (let* ((summary (my-package--format-summary operation result))
               (log-file
                (condition-case err
                    (my-package--write-error-log operation result)
                  (error
                   (setq summary
                         (concat summary "\nLog write error: "
                                 (error-message-string err) "\n"))
                   nil)))
               (buffer (get-buffer-create "*Package Maintenance Errors*")))
          (with-current-buffer buffer
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert summary)
              (when log-file
                (insert (format "\nLog: %s\n" log-file)))
              (special-mode)))
          (display-buffer buffer)
          (message "%s completed with %d error(s); Emacs was not restarted%s"
                   operation (length failures)
                   (if log-file (format "; log: %s" log-file) "")))
      (message "%s completed successfully; Emacs will restart in 3 seconds."
               operation)
      (when (timerp my-package--restart-timer)
        (cancel-timer my-package--restart-timer))
      (setq my-package--restart-timer
            (run-at-time 3 nil #'restart-emacs)))
    result))

(defun my-install-packages--run ()
  "Install dependencies and return a structured result without restarting."
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
    (my-package--result success-count (nreverse failed))))

(defun my-install-packages ()
  "Install dependencies, report errors, and restart Emacs on success.

Network access occurs only while a package or grammar is missing.  Failures
are collected in ~/.emacs.d/log/ and prevent the automatic restart."
  (interactive)
  (my-package--finish "Package installation" (my-install-packages--run)))

(defun my-package--upgrade-archive-packages ()
  "Upgrade archive packages and return a structured result."
  (let ((success-count 0)
        failed
        upgradeable)
    (condition-case err
        (progn
          (message "Refreshing package archives...")
          (redisplay)
          (package-refresh-contents)
          (setq upgradeable
                (package--upgradeable-packages
                 package-install-upgrade-built-in)))
      (error
       (push (cons 'package-archive-refresh (error-message-string err)) failed)))
    (cl-loop for package in upgradeable
             for index from 1
             do (message "Updating archive package %d/%d: %s..."
                         index (length upgradeable) package)
             do (redisplay)
             do (condition-case err
                    (progn
                      (package-upgrade package)
                      (cl-incf success-count))
                  (error
                   (push (cons package (error-message-string err)) failed))))
    (my-package--result success-count (nreverse failed))))

(defun my-package--process-error-output (process)
  "Return concise diagnostic output for failed PROCESS."
  (let ((buffer (process-buffer process)))
    (if (buffer-live-p buffer)
        (with-current-buffer buffer
          (let* ((output (string-trim (buffer-string)))
                 (limit 4000))
            (if (> (length output) limit)
                (concat "..." (substring output (- (length output) limit)))
              output)))
      (format "Process exited with status %d" (process-exit-status process)))))

(defun my-package--upgrade-vc-packages ()
  "Upgrade installed VC packages, wait for them, and return their result."
  (let ((success-count 0)
        failed)
    (dolist (package package-alist)
      (dolist (descriptor (cdr package))
        (when (package-vc-p descriptor)
          (let ((name (package-desc-name descriptor))
                (checkout-dir
                 (file-name-as-directory
                  (expand-file-name (package-vc--checkout-dir descriptor)))))
            (message "Updating VC package: %s..." name)
            (redisplay)
            (condition-case err
                (let* ((processes-before (process-list))
                       (original-message (symbol-function 'message))
                       reported-errors
                       update-processes)
                  ;; `package-vc-upgrade' starts `vc-pull' asynchronously but
                  ;; normally returns nil because `vc-pull' discards the Git
                  ;; process value.  Capture explicit errors while locating
                  ;; the new process independently.
                  (cl-letf (((symbol-function 'message)
                             (lambda (format-string &rest arguments)
                               (let ((text
                                      (if (stringp format-string)
                                          (apply #'format-message
                                                 format-string arguments)
                                        (format "%s" format-string))))
                                 (when (string-match-p
                                        "\\`Failed to \\(fetch\\|activate\\):"
                                        text)
                                   (push text reported-errors))
                                 (apply original-message
                                        format-string arguments)))))
                    (package-vc-upgrade descriptor)
                    (setq update-processes
                          (seq-filter
                           (lambda (process)
                             (and (not (memq process processes-before))
                                  (buffer-live-p (process-buffer process))
                                  (with-current-buffer (process-buffer process)
                                    (file-equal-p default-directory checkout-dir))))
                           (process-list)))
                    (dolist (process update-processes)
                      (while (process-live-p process)
                        (accept-process-output process 0.2))))
                  (let ((failed-processes
                         (seq-filter
                          (lambda (process)
                            (not (zerop (process-exit-status process))))
                          update-processes)))
                    (cond
                     (reported-errors
                      (push (cons name
                                  (string-join (nreverse reported-errors) "\n"))
                            failed))
                     (failed-processes
                      (push (cons name
                                  (mapconcat
                                   #'my-package--process-error-output
                                   failed-processes "\n"))
                            failed))
                     (t
                      (cl-incf success-count)))))
              (error
               (push (cons name (error-message-string err)) failed)))))))
    (my-package--result success-count (nreverse failed))))

(defun my-install-packages-update ()
  "Update everything, log errors, and restart Emacs on complete success.

Archive packages from GNU ELPA, NonGNU ELPA and MELPA are refreshed and
upgraded first.  Packages installed from Git repositories are upgraded next.
VC updates are allowed to finish before continuing.  Finally, the internal
installer adds anything newly introduced to the
configuration, rebuilds native dependencies such as vterm and PDF Tools, and
installs missing tree-sitter grammars.

Any failure is summarized in ~/.emacs.d/log/ and prevents a restart.  When
every stage succeeds, completion is announced and Emacs restarts after three
seconds."
  (interactive)
  (let ((archive-result (my-package--upgrade-archive-packages))
        (vc-result (my-package--upgrade-vc-packages)))
    (message "Installing and rebuilding configuration dependencies...")
    (my-package--finish
     "Package update"
     (my-package--merge-results archive-result vc-result
                                (my-install-packages--run)))))

(provide 'init-package)

;;; init-package.el ends here
