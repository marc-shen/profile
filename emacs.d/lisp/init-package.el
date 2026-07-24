;;; init-package.el --- Package management -*- lexical-binding: t; -*-

(require 'package)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

; (package-initialize)

; (unless package-archive-contents
;   (package-refresh-contents))

; (unless (package-installed-p 'use-package)
  ; (package-install 'use-package))

(require 'use-package)

(setq use-package-always-ensure t)
(setq use-package-always-defer t)

(provide 'init-package)
