;;; init-restart.el --- Restart through the owning service manager -*- lexical-binding: t; -*-
(require 'subr-x)

(defun my-emacs--systemd-user-service-p ()
  "Return non-nil when this Emacs is the systemd user emacs.service process."
  (when (and (eq system-type 'gnu/linux)
             (daemonp)
             (executable-find "systemctl"))
    (with-temp-buffer
      (let ((status
             (call-process "systemctl" nil t nil
                           "--user" "show" "emacs.service"
                           "--property=MainPID" "--value")))
        (and (integerp status)
             (zerop status)
             (= (emacs-pid)
                (string-to-number (string-trim (buffer-string)))))))))

(defun my-emacs--launchd-user-service-p ()
  "Return non-nil only when launchd owns this exact daemon process."
  (when (and (eq system-type 'darwin) (daemonp))
    (with-temp-buffer
      (let ((status (call-process "/bin/launchctl" nil t nil "print"
                                  (format "gui/%d/org.gnu.emacs.daemon" (user-uid)))))
        (and (integerp status) (zerop status)
             (goto-char (point-min))
             (re-search-forward "^[ \t]*pid = \\([0-9]+\\)[ \t]*$" nil t)
             (= (emacs-pid) (string-to-number (match-string 1))))))))

(defun my-emacs--reopen-after-exit (bundle pid)
  "Launch an independent Client helper to reopen after PID exits.
LaunchServices keeps the helper outside the daemon's launchd process group."
  (let ((status (call-process "/usr/bin/open" nil nil nil "-n" bundle "--args"
                              (format "--after-pid=%d" pid) "--new-window")))
    (unless (and (integerp status) (zerop status))
      (error "Unable to launch Emacs Client restart helper (status %s)" status))))

(defun my-restart-emacs ()
  "Restart through launchd or systemd when either owns the current daemon.
On macOS, use normal save/exit confirmation, let launchd start a fresh
process through the runtime wrapper, then reopen a focused client window.
Other sessions retain the built-in `restart-emacs' behavior."
  (interactive)
  (cond
   ((my-emacs--launchd-user-service-p)
    (let ((bundle (expand-file-name "~/Applications/Emacs Client.app"))
          (pid (emacs-pid)))
      (unless (file-executable-p (expand-file-name "Contents/MacOS/emacs-client-launcher" bundle))
        (user-error "Emacs Client is missing; deploy the macOS Client application first"))
      ;; A temporary exit hook runs only after all save/quit queries succeed.
      ;; Canceling any prompt leaves no helper, timer, or service restart behind.
      (let ((kill-emacs-hook
             (cons (lambda () (my-emacs--reopen-after-exit bundle pid))
                   kill-emacs-hook)))
        (save-buffers-kill-emacs))))
   ((my-emacs--systemd-user-service-p)
    (with-temp-buffer
      (let ((status (call-process "systemctl" nil t nil "--user" "--no-block"
                                  "restart" "emacs.service")))
        (unless (and (integerp status) (zerop status))
          (error "Failed to restart emacs.service: %s"
                 (string-trim (buffer-string))))
        (message "Requested restart of systemd user service emacs.service"))))
   (t (restart-emacs))))

(provide 'init-restart)
;;; init-restart.el ends here
