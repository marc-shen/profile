;;; init-macos-dock.el --- Stable Dock policy for NS daemons -*- lexical-binding: t; -*-

;; Emacs 31 nsfns.m requests Regular policy for EVERY new NS frame, including
;; Corfu's non-focusable child frames. Hiding the Dock tile afterwards causes
;; a Regular -> Accessory transition which can deactivate the editing app.
;; Intercept that promotion before it happens, using a daemon-only module.

(defvar init-ui-macos-dock-module
  (expand-file-name "../Emacs Client.app/Contents/Resources/dock-policy.dylib"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Native module built by build-emacs-client.sh.")

(declare-function profile-macos-dock-guard "dock-policy" (enable))
(declare-function profile-macos-dock-guard-status "dock-policy" ())

;; Hot reload must remove the old post-creation workaround before installing
;; the guard.  Corfu suppresses frame hooks, so ordinary hooks cannot fix this.
(remove-hook 'after-make-frame-functions 'init-ui-hide-macos-daemon-dock-icon)
(advice-remove 'make-frame 'init-ui-macos-frame-without-dock-icon)

(when (and (eq system-type 'darwin) (daemonp) (featurep 'ns))
  (condition-case err
      (progn
        (unless (fboundp 'profile-macos-dock-guard)
          (module-load init-ui-macos-dock-module))
        (profile-macos-dock-guard t))
    ;; Do not fall back to the policy flip that loses keyboard focus.  An
    ;; extra Dock icon is preferable to interrupting typing on every popup.
    (error (display-warning
            'init-macos-dock
            (format "Dock policy guard unavailable: %s. Run bash emacs.d/build-emacs-client.sh; a second Dock icon may appear."
                    (error-message-string err))))))

(provide 'init-macos-dock)
;;; init-macos-dock.el ends here
