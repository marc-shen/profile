;;; test-emacs-stdin.el --- Import and waiting-client regression tests -*- lexical-binding: t; -*-
(require 'ert)
(load (expand-file-name "../scripts/emacs-stdin.el"
                        (file-name-directory load-file-name)) nil t)

(ert-deftest profile-stdin-is-editable-text-not-code ()
  (let ((file (make-temp-file "stdin-test"))
        (payload "中文 \"quoted\" \\ backslash\n(error \"not evaluated\")\n")
        buffer)
    (unwind-protect
        (progn
          (with-temp-file file (insert payload))
          (profile-emacs-stdin file temporary-file-directory nil)
          (setq buffer (window-buffer (selected-window)))
          (set-buffer buffer)
          (should (equal (buffer-string) payload))
          (should-not buffer-file-name)
          (should-not buffer-read-only)
          (should (eq major-mode 'text-mode))
          (should (buffer-modified-p))
          (should-not (file-exists-p file)))
      (when (file-exists-p file) (delete-file file))
      (when buffer (set-buffer-modified-p nil) (kill-buffer buffer)))))

(ert-deftest profile-stdin-wait-registers-and-retains-buffer ()
  (let ((file (make-temp-file "stdin-test"))
        (client (make-pipe-process :name "stdin-test-client" :noquery t))
        (previous (frame-parameter nil 'client))
        buffer)
    (unwind-protect
        (progn
          (set-frame-parameter nil 'client client)
          (with-temp-file file (insert "keep this input"))
          (profile-emacs-stdin file temporary-file-directory t)
          (setq buffer (window-buffer (selected-window)))
          (set-buffer buffer)
          (should (memq client server-buffer-clients))
          (should (memq buffer (process-get client 'buffers)))
          ;; Batch Emacs has only one frame; don't ask server teardown to close it.
          (set-frame-parameter nil 'client previous)
          ;; Even users enabling server-kill-new-buffers retain imported text.
          (let ((server-clients (list client))
                (server-kill-new-buffers t))
            (server-buffer-done buffer))
          (should (buffer-live-p buffer))
          (should-not (process-live-p client))
          (should (equal (with-current-buffer buffer (buffer-string)) "keep this input")))
      (set-frame-parameter nil 'client previous)
      (when (process-live-p client) (delete-process client))
      (when (file-exists-p file) (delete-file file))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer)))))
