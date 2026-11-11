;;; init-input-source.el --- Focus-safe macOS modal input -*- lexical-binding: t; -*-

;; Keep the macOS input source on Squirrel in both Helix states.  Normal
;; requests Rime ASCII mode; insert leaves that mode to the user's Shift key.
;; The helper checks the OS foreground PID before selecting Rime or sending
;; its ASCII command.  Do not switch to ABC or save/restore system layouts.

(defvar my-input-source-program
  (expand-file-name "../Emacs Client.app/Contents/Resources/input-source"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Native input source helper, built by build-emacs-client.sh.")

(defvar my-input-source-rime "im.rime.inputmethod.Squirrel.Hans"
  "Squirrel source to select if Emacs arrives from another input method.")

(defvar my-input-source--focus-frame nil
  "Last known focused editing frame, or nil.")
(defvar my-input-source--timer nil
  "Pending focus-settle timer, or nil.")

(defun my-input-source--focused-frame ()
  "Return the selected, focused NS frame, excluding child frames.
Unknown focus is not proof of foreground ownership.  The helper additionally
checks the OS foreground PID because Emacs focus events can arrive late."
  (let ((frame (selected-frame)))
    (and (eq system-type 'darwin)
         (eq (framep frame) 'ns)
         (not (frame-parent frame))
         (eq (frame-focus-state frame) t)
         frame)))

(defun my-input-source--run (&rest arguments)
  "Run the foreground-guarded helper with ARGUMENTS.
Return (PREVIOUS CURRENT) source IDs on success, otherwise nil."
  (when (file-executable-p my-input-source-program)
    (with-temp-buffer
      (when (eq 0 (apply #'call-process my-input-source-program nil '(t nil) nil
                        (number-to-string (emacs-pid)) arguments))
        (let ((sources (split-string (buffer-string) "\n" t)))
          (when (= (length sources) 2) sources))))))

(defun my-input-source--sync (frame)
  "Keep Rime selected; request English only in FRAME's Helix normal state."
  (when (and frame (eq frame (my-input-source--focused-frame)))
    (with-current-buffer (window-buffer (frame-selected-window frame))
      (when-let* ((sources (my-input-source--run "rime" my-input-source-rime)))
        (when (and (bound-and-true-p helix-normal-mode)
                   (not (bound-and-true-p helix-insert-mode)))
          (if (equal (car sources) (cadr sources))
              (my-input-source--run "rime-ascii")
            ;; Selecting Rime may create its input controller asynchronously.
            ;; Let it settle; recheck focus and state before requesting ASCII.
            ;; Entering insert or leaving Emacs cancels this pending request.
            (my-input-source--schedule frame)))))))

(defun my-input-source--schedule (frame)
  "Schedule one guarded synchronization for FRAME after input focus settles."
  (my-input-source--cancel-timer)
  (setq my-input-source--timer
        (run-at-time 0.1 nil
                     (lambda ()
                       (setq my-input-source--timer nil)
                       (my-input-source--sync frame)))))

(defun my-input-source--cancel-timer ()
  "Discard pending work on focus/state changes and configuration reloads."
  (when (timerp my-input-source--timer)
    (cancel-timer my-input-source--timer))
  (setq my-input-source--timer nil))

(defun my-input-source-follow-helix ()
  "Change input source only for the buffer the user is actually editing."
  (when-let* ((frame (my-input-source--focused-frame)))
    (when (eq (current-buffer) (window-buffer (frame-selected-window frame)))
      (my-input-source--cancel-timer)
      (my-input-source--sync frame))))

(defun my-input-source-follow-focus ()
  "Handle actual focus transitions without changing application focus.
Allow macOS to finish restoring its input source first.  Insert keeps Rime's
current Chinese/English mode; only normal requests ASCII mode."
  (let ((frame (my-input-source--focused-frame)))
    (unless (eq frame my-input-source--focus-frame)
      (my-input-source--cancel-timer)
      (setq my-input-source--focus-frame frame)
      (when frame (my-input-source--schedule frame)))))

(defun my-input-source-follow-window (frame)
  "Apply input policy after FRAME's selected buffer changes."
  (my-input-source--sync frame))

;; Remove old registrations and pending CLI jobs when loading this fix into a
;; running daemon.  Do not touch the actual system Squirrel process.
(remove-hook 'helix-insert-mode-hook #'my-input-source-follow-helix)
(remove-function after-focus-change-function #'my-input-source-follow-focus)
(my-input-source--cancel-timer)
(dolist (process (process-list))
  (when (string-match-p "\\`squirrel-\\(?:select\\|control\\)\\(?:<[0-9]+>\\)?\\'"
                        (process-name process))
    (set-process-sentinel process #'ignore)
    (when (process-live-p process) (delete-process process))))

;; Discard state from the previous ABC-based implementation on hot reload.
(dolist (frame (frame-list))
  (set-frame-parameter frame 'my-input-source-restore nil))

(when (eq system-type 'darwin)
  ;; Normal's hook runs after Helix finishes leaving insert.  A foreground
  ;; insert transition only ensures Rime is selected; it never changes ASCII.
  (add-hook 'helix-normal-mode-hook #'my-input-source-follow-helix)
  (add-hook 'helix-insert-mode-hook #'my-input-source-follow-helix)
  (add-function :after after-focus-change-function #'my-input-source-follow-focus)
  (add-hook 'window-selection-change-functions #'my-input-source-follow-window)
  (add-hook 'window-buffer-change-functions #'my-input-source-follow-window)
  (setq my-input-source--focus-frame nil)
  (my-input-source-follow-focus))

(provide 'init-input-source)
;;; init-input-source.el ends here
