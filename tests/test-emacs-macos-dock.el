;;; test-emacs-macos-dock.el --- Live NS daemon regression tests -*- lexical-binding: t; -*-

;; Load into a configured macOS daemon with an existing GUI frame, then run
;; (ert-run-tests-batch "profile-macos-dock-").  Other environments skip.
;; Tests own and remove their child frames; existing frames/buffers stay open.
(require 'ert)

(defun profile-test-dock-policy ()
  (ns-do-applescript
   (concat "use framework \"AppKit\"\n"
           "return current application's NSApplication's sharedApplication()'s "
           "activationPolicy()")))

(defun profile-test-dock-parent ()
  (unless (and (eq system-type 'darwin) (daemonp) (featurep 'ns)
               (fboundp 'init-ui-macos-frame-without-dock-icon))
    (ert-skip "Requires a configured macOS daemon"))
  (let ((parent (seq-find (lambda (frame)
                            (and (eq (framep frame) 'ns)
                                 (not (frame-parent frame))))
                          (frame-list))))
    (unless parent (ert-skip "Requires an existing NS frame"))
    parent))

(ert-deftest profile-macos-dock-suppressed-frame-hooks ()
  (let ((parent (profile-test-dock-parent)) child)
    (unwind-protect
        (with-selected-frame parent
          (let ((after-make-frame-functions nil))
            (setq child (make-frame
                         `((parent-frame . ,parent)
                           (name . "profile-dock-test")
                           (minibuffer . nil) (visibility . nil)
                           (width . 10) (height . 2)))))
          (should (frame-live-p child))
          (should (eq (frame-parent child) parent))
          (should (= (profile-test-dock-policy) 1)))
      (when (frame-live-p child) (delete-frame child t)))))

(ert-deftest profile-macos-dock-corfu-create-and-reuse ()
  (let ((parent (profile-test-dock-parent)) child)
    (unless (fboundp 'corfu--make-frame) (ert-skip "Requires loaded Corfu"))
    (unwind-protect
        (with-selected-frame parent
          (with-temp-buffer
            (insert "completion test")
            (dotimes (_ 3)
              (setq child (corfu--make-frame child 0 0 160 40))
              (should (frame-live-p child))
              (should (= (profile-test-dock-policy) 1))
              (make-frame-invisible child))))
      (when (frame-live-p child) (delete-frame child t)))))
