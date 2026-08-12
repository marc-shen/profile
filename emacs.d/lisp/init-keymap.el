;;; init-keymap.el --- Global key bindings -*- lexical-binding: t; -*-

(global-set-key (kbd "C-c h") #'windmove-left)
(global-set-key (kbd "C-c j") #'windmove-down)
(global-set-key (kbd "C-c k") #'windmove-up)
(global-set-key (kbd "C-c l") #'windmove-right)
(windmove-default-keybindings)

(global-set-key (kbd "C-c w v") #'split-window-right)
(global-set-key (kbd "C-c w s") #'split-window-below)
(global-set-key (kbd "C-c w d") #'delete-window)
(global-set-key (kbd "C-c w o") #'delete-other-windows)
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
