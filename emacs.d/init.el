;;; init.el --- Main Emacs configuration -*- lexical-binding: t; -*-

;; Where the tracked configuration lives.  This file is symlinked into
;; ~/.emacs.d, so the value is the repository whenever `load' resolves the link.
;; It is used for `load-path' only.
(defconst init-config-directory
  (file-name-directory (or load-file-name buffer-file-name)))

;; `user-emacs-directory' is deliberately left at the value Emacs computed at
;; startup, which is the real ~/.emacs.d (or its XDG equivalent).  Everything
;; downloaded or generated -- `package-user-dir', `custom-file', eln-cache,
;; `init-var-directory' -- hangs off it and therefore stays out of the
;; repository, which carries configuration only.  Pointing it at
;; `init-config-directory' instead would install a second copy of every package
;; into the working tree as soon as `load' resolved the symlink.
(add-to-list 'load-path (expand-file-name "lisp" init-config-directory))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file 'noerror 'nomessage)

(require 'init-package)
(require 'init-base)
(require 'init-ui)
(require 'init-theme)
(require 'init-keymap)
(require 'init-completion)
(require 'init-project)
(require 'init-terminal)
(require 'init-agent)
(require 'init-development)
;; After init-development so `multiple-cursors' is on the load path when
;; helix-mode probes for its integrations.
(require 'init-helix)
;; macOS only -- it drives Squirrel, and there is nothing for it to do on a
;; Linux box.  After init-helix, whose `helix-insert-mode-hook' it hangs off.
(when (eq system-type 'darwin)
  (require 'init-input-source))
(require 'init-python)
(require 'init-c)
(require 'init-fortran)
(require 'init-latex)
(require 'init-markdown)
(require 'init-pdf)
(require 'init-browser)
(require 'init-org)
(require 'init-git)

;; Restore normal garbage-collection settings after startup.
(setq gc-cons-threshold (* 64 1024 1024)
      gc-cons-percentage 0.1)

(provide 'init)

;;; init.el ends here
