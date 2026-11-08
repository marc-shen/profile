;;; test-emacs-macos-dock.el --- Live NS daemon regression tests -*- lexical-binding: t; -*-

;; Load into a configured macOS daemon with an existing GUI frame, then run
;; (ert-run-tests-batch "profile-macos-dock-").  Other environments skip.
;; Tests own and remove their child frames; existing frames/buffers stay open.
(require 'ert)
(require 'seq)

(defvar corfu--frame)
(defvar corfu-popupinfo--frame)
(defvar corfu-auto)
(defvar corfu-auto-delay)
(defvar corfu-auto-prefix)

(defun profile-test-dock-frontmost-pid ()
  (ns-do-applescript
   (concat "use framework \"AppKit\"\n"
           "return current application's NSWorkspace's sharedWorkspace()'s "
           "frontmostApplication()'s processIdentifier()")))

(defun profile-test-dock-changes ()
  (plist-get (profile-macos-dock-guard-status) :policy-changes))

(defun profile-test-dock-policy ()
  (ns-do-applescript
   (concat "use framework \"AppKit\"\n"
           "return current application's NSApplication's sharedApplication()'s "
           "activationPolicy()")))

(defun profile-test-dock-parent ()
  (unless (and (eq system-type 'darwin) (daemonp) (featurep 'ns)
               (fboundp 'profile-macos-dock-guard-status)
               (plist-get (profile-macos-dock-guard-status) :enabled))
    (ert-skip "Requires a configured macOS daemon"))
  (let ((parent (seq-find (lambda (frame)
                            (and (eq (framep frame) 'ns)
                                 (not (frame-parent frame))))
                          (frame-list))))
    (unless parent (ert-skip "Requires an existing NS frame"))
    parent))

(ert-deftest profile-macos-dock-suppressed-frame-hooks ()
  (let* ((parent (profile-test-dock-parent))
         (changes (profile-test-dock-changes))
         (foreground (profile-test-dock-frontmost-pid)) child)
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
          (should (= (profile-test-dock-policy) 1))
          (sit-for 0.1)
          ;; Checking only the final policy missed the Regular->Accessory
          ;; transition. There must be NO native policy changes at all.
          (should (= (profile-test-dock-changes) changes))
          (should (= (profile-test-dock-frontmost-pid) foreground)))
      (when (frame-live-p child) (delete-frame child t)))))

(ert-deftest profile-macos-dock-corfu-create-and-reuse ()
  (let* ((parent (profile-test-dock-parent))
         (changes (profile-test-dock-changes))
         (foreground (profile-test-dock-frontmost-pid)) child)
    (unless (fboundp 'corfu--make-frame) (ert-skip "Requires loaded Corfu"))
    (unwind-protect
        (with-selected-frame parent
          (with-temp-buffer
            (insert "completion test")
            (dotimes (_ 3)
              (setq child (corfu--make-frame child 0 0 160 40))
              (should (frame-live-p child))
              (should (= (profile-test-dock-policy) 1))
              (sit-for 0.1)
              (should (= (profile-test-dock-changes) changes))
              (should (= (profile-test-dock-frontmost-pid) foreground))
              (make-frame-invisible child))))
      (when (frame-live-p child) (delete-frame child t)))))

(ert-deftest profile-macos-dock-first-completion-keeps-typing-focus ()
  (let* ((parent (profile-test-dock-parent))
         (changes (profile-test-dock-changes))
         (corfu--frame nil)
         (corfu-popupinfo--frame nil)
         (corfu-auto t) (corfu-auto-prefix 2) (corfu-auto-delay 0.1))
    (unless (and (fboundp 'corfu-mode)
                 (= (profile-test-dock-frontmost-pid) (emacs-pid)))
      (ert-skip "Requires foreground Emacs with Corfu"))
    (unwind-protect
        (with-selected-frame parent
          (save-window-excursion
            (with-temp-buffer
              (lisp-interaction-mode)
              (switch-to-buffer (current-buffer))
              (corfu-mode 1)
              (when (fboundp 'helix--switch-state) (helix--switch-state 'insert))
              (let ((window (selected-window)))
                ;; Use actual self-insert commands and Corfu's auto timer,
                ;; exactly the scratch-buffer "pr" trigger from the report.
                (execute-kbd-macro "pr")
                (sit-for 0.35)
                (should (frame-live-p corfu--frame))
                (should (frame-visible-p corfu--frame))
                (should (eq (frame-parent corfu--frame) parent))
                (should (= (profile-test-dock-changes) changes))
                (should (= (profile-test-dock-frontmost-pid) (emacs-pid)))
                (should (eq (frame-focus-state parent) t))
                (should (eq (selected-window) window))
                (execute-kbd-macro "i")
                (sit-for 0.15)
                (should (equal (buffer-string) "pri"))
                (should (= (profile-test-dock-frontmost-pid) (emacs-pid)))
                (should (= (profile-test-dock-changes) changes))
                (corfu-quit)))))
      (dolist (child (list corfu-popupinfo--frame corfu--frame))
        (when (frame-live-p child) (delete-frame child t))))))
