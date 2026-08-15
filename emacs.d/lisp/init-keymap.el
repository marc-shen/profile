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
