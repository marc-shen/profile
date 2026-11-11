;;; init-terminal.el --- Terminal integration -*- lexical-binding: t; -*-

;; vterm is a native-module terminal emulator.  It is intentionally lazy so
;; its shared library is compiled only when the terminal is first opened.
(use-package vterm
  :if (package-installed-p 'vterm)
  :commands (vterm vterm-other-window)
  :bind (("C-c v" . vterm)
         ("C-c V" . vterm-other-window))
  :custom
  (vterm-max-scrollback 10000))

(provide 'init-terminal)

;;; init-terminal.el ends here
