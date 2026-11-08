;;; test-emacs-input-source.el --- Rime-only focus regressions -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(load (expand-file-name "../emacs.d/lisp/init-input-source.el"
                        (file-name-directory load-file-name)) nil t)
(defvar-local helix-normal-mode nil)
(defvar-local helix-insert-mode nil)

(defmacro profile-input-with-context (&rest body)
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (with-temp-buffer
       (switch-to-buffer (current-buffer))
       (setq-local helix-normal-mode t helix-insert-mode nil)
       (let ((frame (selected-frame))
             (my-input-source--timer nil)
             (my-input-source--focus-frame nil)
             (focused t) calls
             (reply '("rime" "rime")))
         (unwind-protect
             (cl-letf (((symbol-function 'my-input-source--focused-frame)
                        (lambda () (and focused frame)))
                       ((symbol-function 'my-input-source--run)
                        (lambda (&rest args) (push args calls) reply)))
               ,@body)
           (my-input-source--cancel-timer))))))

(ert-deftest profile-input-normal-uses-rime-ascii-not-system-layout ()
  (profile-input-with-context
    (my-input-source-follow-helix)
    (should (equal (reverse calls)
                   (list (list "rime" my-input-source-rime) '("rime-ascii"))))
    (should-not (frame-parameter frame 'my-input-source-restore))))

(ert-deftest profile-input-insert-and-window-change-preserve-rime-mode ()
  (profile-input-with-context
    (setq helix-normal-mode nil helix-insert-mode t)
    (my-input-source-follow-helix)
    (my-input-source-follow-window frame)
    (should (equal calls (make-list 2 (list "rime" my-input-source-rime))))))

(ert-deftest profile-input-exempt-buffer-keeps-rime-without-forcing-english ()
  (profile-input-with-context
    (setq helix-normal-mode nil helix-insert-mode nil)
    (my-input-source-follow-window frame)
    (should (equal calls (list (list "rime" my-input-source-rime))))))

(ert-deftest profile-input-background-or-inactive-buffer-does-nothing ()
  (profile-input-with-context
    (setq focused nil)
    (my-input-source-follow-helix)
    (my-input-source-follow-window frame)
    (setq focused t)
    (with-temp-buffer (my-input-source-follow-helix))
    (should-not calls)))

(ert-deftest profile-input-reads-displayed-buffer-not-current-buffer ()
  (profile-input-with-context
    (with-temp-buffer (my-input-source--sync frame))
    (should (equal (car calls) '("rime-ascii")))))

(ert-deftest profile-input-selection-settles-before-ascii ()
  (profile-input-with-context
    (let (callback)
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (_delay _repeat function) (setq callback function) nil)))
        (setq reply '("ABC" "rime"))
        (my-input-source-follow-helix)
        (should (equal calls (list (list "rime" my-input-source-rime))))
        (setq reply '("rime" "rime"))
        (funcall callback)
        (should (equal (car calls) '("rime-ascii")))))))

(ert-deftest profile-input-stale-callback-never-forces-ascii-in-insert ()
  (profile-input-with-context
    (let (callback)
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (_delay _repeat function) (setq callback function) nil)))
        (my-input-source-follow-focus)
        (setq focused nil)
        (my-input-source-follow-focus)
        (funcall callback)
        (should-not calls)
        (setq focused t helix-normal-mode nil helix-insert-mode t)
        (funcall callback)
        (should (equal calls (list (list "rime" my-input-source-rime))))))))

(ert-deftest profile-input-duplicate-focus-does-not-reschedule ()
  (profile-input-with-context
    (let ((count 0))
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (&rest _) (cl-incf count) nil)))
        (my-input-source-follow-focus)
        (my-input-source-follow-focus)
        (should (= count 1))
        (should-not calls)))))

(ert-deftest profile-input-focus-loss-cancels-timer ()
  (profile-input-with-context
    (my-input-source-follow-focus)
    (should (timerp my-input-source--timer))
    (setq focused nil)
    (my-input-source-follow-focus)
    (should-not my-input-source--timer)))

(ert-deftest profile-input-selection-failure-never-sends-ascii ()
  (profile-input-with-context
    (setq reply nil)
    (my-input-source-follow-helix)
    (should (equal calls (list (list "rime" my-input-source-rime))))))

(ert-deftest profile-input-only-known-ns-foreground-is-eligible ()
  (let ((system-type 'darwin) (kind 'ns) (focus 'unknown) child)
    (cl-letf (((symbol-function 'framep) (lambda (_) kind))
              ((symbol-function 'frame-parent) (lambda (_) child))
              ((symbol-function 'frame-focus-state) (lambda (_) focus)))
      (should-not (my-input-source--focused-frame))
      (setq focus t)
      (should (eq (my-input-source--focused-frame) (selected-frame)))
      (setq child t)
      (should-not (my-input-source--focused-frame))
      (setq child nil kind t)
      (should-not (my-input-source--focused-frame)))))

(ert-deftest profile-input-native-helper-rejects-background-pid ()
  (unless (and (eq system-type 'darwin) (file-executable-p my-input-source-program))
    (ert-skip "Requires built macOS input-source helper"))
  (dolist (command '("rime-ascii" "status"))
    (should (= 3 (call-process my-input-source-program nil nil nil "1" command))))
  (should (= 3 (call-process my-input-source-program nil nil nil
                            "1" "rime" my-input-source-rime))))
