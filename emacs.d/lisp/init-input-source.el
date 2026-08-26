;;; init-input-source.el --- macOS input source follows Helix state -*- lexical-binding: t; -*-

;; Squirrel, the macOS frontend for Rime, has a `vim_mode' application option
;; that drops Rime back to ASCII when ESC is pressed, and `org.gnu.Emacs' --
;; the identifier a frame made by `emacsclient -c' reports, daemon or not -- is
;; the right key for it in ~/Library/Rime/squirrel.custom.yaml.  It still
;; cannot carry modal editing on its own.  `keyDown:' in nsterm.m runs every
;; key through `ns_convert_key' first, and ESC is in that table (0x1B -> 0x1B),
;; so it counts as a function key: Emacs builds the event itself and returns
;; before `interpretKeyEvents', the only call that hands a keystroke to the
;; input method.  Rime sees ESC only while it is composing, and never sees the
;; `j k' escape from init-helix.el at all.
;;
;; Nor can Rime be driven from the outside: Squirrel registers exactly two
;; input sources (Squirrel.Hans and Squirrel.Hant, no ASCII one), `ascii_mode'
;; lives in the librime session inside the Squirrel process, and version 1.1.2
;; exposes only --install/--quit/--reload/--sync.  (Squirrel's master branch
;; has grown `--ascii', `--nascii' and `--getascii', which post a distributed
;; notification the input controller turns into a `set_option' call; once that
;; reaches a stable release, insert state can keep Rime selected and just
;; toggle the option, and no input source has to move at all.)
;;
;; This file is macOS-only twice over: init.el loads it only under `darwin',
;; and `my-input-source--program' checks the system type again, so loading it
;; by hand anywhere else defines a few symbols and installs nothing -- no hook,
;; no advice, no behavior change.  Nothing here is a fallback for fcitx, ibus
;; or any other platform's input method.
;;
;; So Emacs picks the input source and lets Rime's own application options do
;; the rest: insert state selects Rime, and `ascii_mode: true' for
;; org.gnu.Emacs is what makes it come up in English; normal state drops back
;; to ABC, which is what keeps `j' and `k' from feeding a composition.
;; Switching to Chinese inside insert state is then Rime's ordinary toggle, no
;; input source change involved.

(defvar my-input-source-english "com.apple.keylayout.ABC"
  "Input source selected outside `helix-insert-mode'.")

(defvar my-input-source-rime "im.rime.inputmethod.Squirrel.Hans"
  "Input source selected in `helix-insert-mode'.
Rime's own `ascii_mode' decides whether it starts out in English; see the
org.gnu.Emacs entry in ~/Library/Rime/squirrel.custom.yaml.")

(defvar my-input-source-program "macism"
  "Command that selects a macOS input source, given its identifier.")

(defun my-input-source--program ()
  "Return the absolute path of `my-input-source-program', or nil.
Nil off macOS, which is what keeps every entry point below inert there."
  (and (eq system-type 'darwin)
       (executable-find my-input-source-program)))

(defun my-input-source--select (source)
  "Select SOURCE asynchronously.
Asynchronously because `macism' costs about ten milliseconds, and ESC
should not wait for it."
  (when-let* ((program (my-input-source--program)))
    (make-process :name "macism" :noquery t :command (list program source))))

(defun my-input-source-follow-helix ()
  "Select Rime in insert state and ABC everywhere else.

Runs from `helix-insert-mode-hook', which fires in both directions:
`helix--switch-state' turns the outgoing state's minor mode off before it
turns the incoming one on, so leaving insert state triggers this once,
whether ESC or `j k' did it."
  (my-input-source--select (if (bound-and-true-p helix-insert-mode)
                               my-input-source-rime
                             my-input-source-english)))

(defun my-input-source-follow-focus ()
  "Park the keyboard on ABC when Emacs regains focus outside insert state.
Without this, coming back from an application where Rime was composing
Chinese would leave the next `j' or `k' feeding the composition instead
of moving point."
  (when (and (seq-some #'frame-focus-state (frame-list))
             (not (bound-and-true-p helix-insert-mode)))
    (my-input-source--select my-input-source-english)))

;; Guarded, not unconditional: on a machine without `macism' -- or on any
;; system that is not macOS -- the hooks are never installed at all.
(when (my-input-source--program)
  (require 'seq)
  (add-hook 'helix-insert-mode-hook #'my-input-source-follow-helix)
  (add-function :after after-focus-change-function #'my-input-source-follow-focus))

(provide 'init-input-source)

;;; init-input-source.el ends here
