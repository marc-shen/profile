;;; init-macos-dock.el --- Native menu bar for macOS Emacs -*- lexical-binding: t; -*-

;; Accessory applications have no native menu bar. Keep Emacs Regular for its
;; entire GUI lifetime, including completion child-frame creation. In particular,
;; never hide its Dock icon after make-frame: that can deactivate the editor.

(require 'seq)

(declare-function profile-macos-dock-guard "dock-policy" (enable))

;; Migrate a running daemon from either previous Dock-hiding implementation.
(remove-hook 'after-make-frame-functions 'init-ui-hide-macos-daemon-dock-icon)
(advice-remove 'make-frame 'init-ui-macos-frame-without-dock-icon)

(when (and (eq system-type 'darwin) (featurep 'ns))
  (when (fboundp 'profile-macos-dock-guard)
    (profile-macos-dock-guard nil))
  (menu-bar-mode 1)
  ;; A fresh daemon has no NS application yet. Its first GUI frame naturally
  ;; requests Regular policy; do not create an AppKit singleton prematurely.
  (when (seq-some (lambda (frame) (eq (framep frame) 'ns)) (frame-list))
    (ns-do-applescript
     (concat "use framework \"AppKit\"\n"
             "current application's NSApplication's sharedApplication()'s "
             "setActivationPolicy:0"))))

(defvar init-ui-macos-client-menu-module
  (expand-file-name "../Emacs Client.app/Contents/Resources/client-menu.dylib"
                    (file-name-directory (or load-file-name buffer-file-name))))
(declare-function profile-macos-client-menu-install "client-menu" ())

(defvar init-ui-macos-dock-resident-module
  (expand-file-name "dock-resident.dylib"
                    (file-name-directory init-ui-macos-client-menu-module)))
(declare-function profile-macos-dock-resident "dock-resident" (enable))

(defun init-ui-keep-client-in-dock (&optional _frame)
  "Keep the unified native daemon in the Dock after its last window closes."
  (unless (fboundp 'profile-macos-dock-resident)
    (module-load init-ui-macos-dock-resident-module))
  (profile-macos-dock-resident t))

(defun init-ui-release-client-dock-policy ()
  "Allow native shutdown policy changes when the daemon actually exits."
  (when (fboundp 'profile-macos-dock-resident)
    (profile-macos-dock-resident nil)))

(defun init-ui-install-client-dock-menu (&optional frame)
  "Add recovery to the native Dock menu when FRAME belongs to the Client bundle."
  (when (and (eq system-type 'darwin) (daemonp)
             (eq (framep (or frame (selected-frame))) 'ns)
             (not (frame-parent (or frame (selected-frame)))))
    (unless (fboundp 'profile-macos-client-menu-install)
      (module-load init-ui-macos-client-menu-module))
    (profile-macos-client-menu-install)))

(when (and (eq system-type 'darwin) (daemonp) (featurep 'ns))
  (add-hook 'after-make-frame-functions #'init-ui-keep-client-in-dock)
  (add-hook 'kill-emacs-hook #'init-ui-release-client-dock-policy)
  ;; A running daemon may already have closed every GUI frame. The module can
  ;; restore its existing NSApp without creating a window or taking focus.
  (init-ui-keep-client-in-dock)
  (add-hook 'after-make-frame-functions #'init-ui-install-client-dock-menu)
  (dolist (frame (frame-list)) (init-ui-install-client-dock-menu frame)))

(provide 'init-macos-dock)
;;; init-macos-dock.el ends here
