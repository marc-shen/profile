;;; init-input-source.el --- Keep Squirrel in ASCII outside Helix insert -*- lexical-binding: t; -*-

;; Recent Squirrel releases expose their Rime session's `ascii_mode' through
;; the command-line switches --ascii, --nascii and --getascii.  That is a
;; better fit for modal editing than changing macOS input sources: Emacs can
;; keep Squirrel selected all the time, while leaving insert state merely
;; changes the existing Rime session back to English.
;;
;; `ascii_mode: true' in ~/Library/Rime/squirrel.custom.yaml supplies the same
;; English default when Squirrel creates a fresh org.gnu.Emacs session.  This
;; file enforces it on every transition to Helix normal state, including ESC
;; and the `j k' escape implemented by init-helix.el.

(defvar my-input-source-rime "im.rime.inputmethod.Squirrel.Hans"
  "Squirrel input source kept active while Emacs has focus.")

(defvar my-squirrel-program
  "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
  "Squirrel executable used to control Rime's ASCII mode.")

(defun my-squirrel--program ()
  "Return the Squirrel executable, or nil when it is unavailable."
  (and (eq system-type 'darwin)
       (file-executable-p my-squirrel-program)
       my-squirrel-program))

(defun my-squirrel--run (&rest arguments)
  "Run Squirrel asynchronously with ARGUMENTS.
Return the process, or nil when the Squirrel executable is unavailable."
  (when-let* ((program (my-squirrel--program)))
    (make-process :name "squirrel-control"
                  :noquery t
                  :command (cons program arguments))))

(defun my-input-source-use-rime-english ()
  "Select Squirrel for Emacs, then put its Rime session in ASCII mode."
  (when-let* ((program (my-squirrel--program)))
    ;; Selection and mode change must be ordered: --ascii targets the active
    ;; Squirrel controller, which may not exist yet if another input source was
    ;; active when Emacs gained focus.
    (make-process
     :name "squirrel-select"
     :noquery t
     :command (list program "--select-input-source" my-input-source-rime)
     :sentinel
     (lambda (process _event)
       (when (and (eq (process-status process) 'exit)
                  (zerop (process-exit-status process)))
         (my-squirrel--run "--ascii"))))))

(defun my-input-source-follow-helix ()
  "Put Rime in English when the current buffer leaves Helix insert state.

Entering insert state deliberately does nothing: Rime therefore starts in
English but remains free to switch to Chinese until ESC or `j k' returns the
buffer to normal state."
  (unless (bound-and-true-p helix-insert-mode)
    (my-squirrel--run "--ascii")))

(defun my-input-source-follow-focus ()
  "Restore Squirrel English when Emacs regains focus in normal state."
  (when (and (seq-some #'frame-focus-state (frame-list))
             (not (bound-and-true-p helix-insert-mode)))
    (my-input-source-use-rime-english)))

;; Loading by hand on another platform is harmless: symbols are defined, but
;; no hooks or processes are installed.
(when (my-squirrel--program)
  (require 'seq)
  (add-hook 'helix-insert-mode-hook #'my-input-source-follow-helix)
  (add-function :after after-focus-change-function #'my-input-source-follow-focus)
  ;; Establish the invariant for the frames that already exist at startup or
  ;; when this file is reloaded.
  (my-input-source-use-rime-english))

(provide 'init-input-source)

;;; init-input-source.el ends here
