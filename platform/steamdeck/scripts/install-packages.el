;;; install-emacs-packages.el --- Install dependencies -*- lexical-binding: t; -*-
(setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.emacs.d")))
(load (expand-file-name "early-init.el" user-emacs-directory) nil nil t)
(load (expand-file-name "init.el" user-emacs-directory) nil nil t)
;; All dependencies are supplied by Pixi.  Never let PDF Tools invoke a
;; distribution package manager when rebuilding its user-owned helper.
(with-eval-after-load 'pdf-tools
  (advice-add 'pdf-tools-install :filter-args
              (lambda (args)
                (list (car args) t (nth 2 args) nil))))
(setq url-request-timeout 60)
;; Use the documented TUNA mirrors for this installation only.  The tracked
;; profile continues to use the author's original package archive settings.
(when (getenv "DECK_ELPA_MIRROR")
  (setq package-archives
        '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
          ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
          ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/"))))
(let* ((result (my-install-packages--run))
       (failures (plist-get result :failures)))
  (princ (my-package--format-summary "Steam Deck package installation" result))
  (when failures
    (my-package--write-error-log "Steam Deck package installation" result))
  (kill-emacs (if failures 1 0)))
