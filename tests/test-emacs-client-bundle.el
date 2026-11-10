;;; test-emacs-client-bundle.el --- Unified native app identity -*- lexical-binding: t; -*-
;; Load into a GUI daemon running from the assembled Emacs Client.app.
(require 'ert)

(ert-deftest profile-unified-native-identity ()
  (unless (and (daemonp) (featurep 'ns)
               (seq-some (lambda (f) (eq (framep f) 'ns)) (frame-list)))
    (ert-skip "Requires a native GUI daemon"))
  (should (equal (ns-do-applescript
                  "use framework \"Foundation\"\nreturn current application's NSBundle's mainBundle()'s bundleIdentifier() as text")
                 "local.marcshen.emacs-client"))
  (should (profile-macos-client-menu-install))
  (should (profile-macos-client-menu-install))
  (should (equal
           (ns-do-applescript
            (concat "use framework \"AppKit\"\n"
                    "set emacsApplication to current application's NSApplication's sharedApplication()\n"
                    "set clientDockMenu to (emacsApplication's delegate()'s applicationDockMenu:emacsApplication)\n"
                    "return (clientDockMenu's itemWithTag:19428)'s target()'s className() as text"))
           "ProfileClientActions"))
  (should (equal
           (ns-do-applescript
            (concat "use framework \"AppKit\"\n"
                    "set emacsApplication to current application's NSApplication's sharedApplication()\n"
                    "set clientDockMenu to (emacsApplication's delegate()'s applicationDockMenu:emacsApplication)\n"
                    "return (clientDockMenu's itemWithTag:19427)'s title() as text"))
           "强制重启 Emacs 后台…")))
