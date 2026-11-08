;;; test-emacs-input-source-live.el --- Rime-only NS regression -*- lexical-binding: t; -*-
;; Run in a configured Emacs while its GUI frame is foreground.
(require 'ert)

(defun profile-input-live-rime-command (argument)
  "Run Rime's supported CLI with ARGUMENT and return its output."
  (with-temp-buffer
    (should (eq 0 (call-process "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
                               nil '(t nil) nil argument)))
    (string-trim (buffer-string))))

(ert-deftest profile-input-live-jk-i-keeps-rime ()
  (unless (and (fboundp 'my-input-source--focused-frame)
               (my-input-source--focused-frame)
               (fboundp 'helix--switch-state))
    (ert-skip "Requires configured Emacs NS frame in foreground"))
  (let* ((frame (selected-frame))
         (source (cadr (my-input-source--run "rime" my-input-source-rime)))
         (previous (profile-input-live-rime-command "--getascii")))
    (should source)
    (unwind-protect
        (save-window-excursion
          (with-temp-buffer
            (switch-to-buffer (current-buffer))
            (helix--switch-state 'insert)
            (dotimes (_ 3)
              ;; Stand in for the user's manual Chinese switch in insert.
              (profile-input-live-rime-command "--nascii")
              (sit-for 0.05)
              (my-input-source-follow-window frame)
              (should (equal (profile-input-live-rime-command "--getascii") "nascii"))
              (should (equal (car (my-input-source--run "status")) source))
              (execute-kbd-macro "jk")
              (sit-for 0.05)
              (should helix-normal-mode)
              (should (equal (car (my-input-source--run "status")) source))
              (should (equal (profile-input-live-rime-command "--getascii") "ascii"))
              (execute-kbd-macro "i")
              (should helix-insert-mode)
              (should (equal (car (my-input-source--run "status")) source))
              (should (equal (profile-input-live-rime-command "--getascii") "ascii")))
            (should (equal (buffer-string) ""))))
      (when (my-input-source--focused-frame)
        (profile-input-live-rime-command
         (if (equal previous "ascii") "--ascii" "--nascii"))))))
