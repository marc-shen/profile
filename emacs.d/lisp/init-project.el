;;; init-project.el --- Project management -*- lexical-binding: t; -*-

(use-package project
  :ensure nil
  :custom
  (project-switch-commands
   '((project-find-file "Find file" ?f) (consult-ripgrep "Ripgrep" ?g)
     (project-find-dir "Find directory" ?d) (project-eshell "Eshell" ?e)
     (magit-project-status "Magit" ?m) (project-compile "Compile" ?c))))

(use-package dired
  :ensure nil
  :custom (dired-kill-when-opening-new-dired-buffer t)
  (dired-listing-switches "-alh --group-directories-first"))
(use-package dired-subtree
  :if (package-installed-p 'dired-subtree)
  :after dired
  :bind (:map dired-mode-map ("TAB" . dired-subtree-toggle)))
(use-package treemacs
  :if (package-installed-p 'treemacs)
  :defer t
  :bind (("C-c t" . treemacs)))

(provide 'init-project)

;;; init-project.el ends here
