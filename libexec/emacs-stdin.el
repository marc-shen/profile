;;; emacs-stdin.el --- Import shell input into the existing daemon -*- lexical-binding: t; -*-

(require 'server)

(defun profile-emacs-stdin (file directory wait)
  "Import FILE into an editable buffer rooted at DIRECTORY.
When WAIT is non-nil, register it with this frame's client for `server-edit'."
  (let ((buffer (generate-new-buffer "*stdin*")))
    (unwind-protect
        (with-current-buffer buffer
          (setq default-directory directory)
          (insert-file-contents file)
          (text-mode)
          (setq buffer-read-only nil)
          (goto-char (point-min))
          (set-buffer-modified-p t)
          (when wait
            (let ((client (frame-parameter nil 'client)))
              (unless (processp client)
                (error "No waiting Emacs client is associated with this frame"))
              (push buffer (process-get client 'buffers))
              (push client server-buffer-clients)
              ;; C-x # releases the shell, but retains unsaved imported text.
              (setq-local server-existing-buffer t)
              (add-hook 'kill-buffer-hook #'server-kill-buffer nil t)))
          (switch-to-buffer buffer)
          nil)
      (delete-file file))))

;;; emacs-stdin.el ends here
