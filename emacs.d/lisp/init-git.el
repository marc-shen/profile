;;; init-git.el --- Git integration -*- lexical-binding: t; -*-

(use-package magit
  :commands (magit-status magit-project-status)
  :bind (("C-x g" . magit-status) ("C-c g b" . magit-blame-addition))
  :config
  ;; Magit's own UI is English; make Git subprocess messages match it without
  ;; changing Emacs's or the operating system's display language.
  (add-to-list 'magit-git-environment "LC_MESSAGES=C")
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(use-package diff-hl
  :demand t
  :config
  :hook ((dired-mode . diff-hl-dired-mode)
         (magit-post-refresh . diff-hl-magit-post-refresh)
         (prog-mode . diff-hl-mode)
         (diff-hl-mode . (lambda ()
                            (unless (display-graphic-p)
                              (diff-hl-margin-mode 1))))))

(provide 'init-git)

;;; init-git.el ends here
