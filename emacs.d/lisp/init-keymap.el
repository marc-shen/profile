;;; init-keymap.el --- Global key bindings -*- lexical-binding: t; -*-

;; Splitting and closing windows are left at their built-in bindings -- `C-x
;; 2/3' and `C-x 0/1' -- rather than aliased to `C-c w v/s/d/o' as they once
;; were.  Moving between windows keeps two: `C-x o' cycles, and the shift-arrow
;; keys below go in a named direction, which is what a layout of more than two
;; windows actually needs.  A third set, `C-c h/j/k/l', used to sit on top of
;; those and is gone: it spent four of the scarce `C-c'-plus-a-letter slots --
;; the ones reserved for the user, which no package may take -- on commands
;; that were already one keystroke away.
;;
;; The shift-arrow keys land in `windmove-mode-map', which is a minor mode map
;; and therefore outranks every major mode: in an Org buffer `S-<left>' moves
;; to the window on the left, not through TODO states.  That is a real trade
;; and it is made knowingly -- Org binds `C-c <left>' and `C-c <right>' to the
;; same commands for exactly this case, so nothing becomes unreachable.
(windmove-default-keybindings)

(global-set-key (kbd "<escape>") #'keyboard-escape-quit)
(global-set-key (kbd "C-c r") #'revert-buffer)
(global-set-key (kbd "C-c c") #'compile)
(global-set-key (kbd "C-c C-c") #'recompile)

;; Bindings that have to work in every buffer, whatever the major mode did with
;; the key.  `global-set-key' is the weakest map there is: a major mode map, any
;; minor mode map and Helix's modal maps all shadow it, and a terminal mode such
;; as vterm swallows the key entirely.  `emulation-mode-map-alists' is consulted
;; before all of those, so a map parked there is the only way to make a key
;; unconditional.  Keep the list short -- everything here is taken away from
;; every mode that might want the key.
(defvar my-override-map (make-sparse-keymap)
  "Keymap for bindings that outrank major and minor mode maps.")

(define-minor-mode my-override-mode
  "Global minor mode holding the bindings in `my-override-map'."
  :init-value t
  :global t
  :keymap my-override-map)

(defvar my-override-map-alist
  `((my-override-mode . ,my-override-map))
  "Entry for `emulation-mode-map-alists' activating `my-override-map'.")

;; A symbol rather than the alist itself, so reloading this file does not add a
;; second, equal-but-not-`eq' entry.
(add-to-list 'emulation-mode-map-alists 'my-override-map-alist)

;; `C-c s' is an Eglot prefix in programming buffers, so the scratch buffer takes
;; `C-c d' -- d as in draft.
(keymap-set my-override-map "C-c d" #'my-scratch-buffer)

;; `C-x K' -- the shifted sibling of `C-x k' -- clears out the file buffers in
;; one go and leaves the `*'-named system buffers alone.
(global-set-key (kbd "C-x K") #'my-kill-all-user-buffers)

;; Reserve a conventional prefix for Git commands such as `C-c g b'.
(define-prefix-command 'init-keymap-git-prefix)
(global-set-key (kbd "C-c g") #'init-keymap-git-prefix)

;; Replace the default transient-input-method binding.
(global-set-key (kbd "C-x |")
                #'my-rotate-windows-clockwise)

(global-set-key (kbd "C-x \\")
                #'my-rotate-windows-counterclockwise)

(keymap-set tab-prefix-map "<tab>" #'tab-next)
(keymap-set tab-prefix-map "<backtab>" #'tab-previous)
(keymap-set tab-prefix-map "S-<tab>" #'tab-previous)


(provide 'init-keymap)

;;; init-keymap.el ends here
