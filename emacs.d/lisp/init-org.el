;;; init-org.el --- Org mode configuration -*- lexical-binding: t; -*-

(use-package org
  :ensure nil
  :hook ((org-mode . visual-line-mode) (org-mode . variable-pitch-mode))
  :bind (("C-c a" . org-agenda) ("C-c n" . org-capture))
  :custom
  (org-directory "~/Documents/org")
  (org-default-notes-file (expand-file-name "inbox.org" org-directory))
  (org-agenda-files (list (expand-file-name "inbox.org" org-directory)
                          (expand-file-name "research.org" org-directory)
                          (expand-file-name "tasks.org" org-directory)))
  (org-log-done 'time)
  (org-log-into-drawer t)
  (org-startup-indented t)
  (org-startup-folded 'content)
  (org-hide-emphasis-markers t)
  (org-pretty-entities t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  ;; Keep confirmation on: Org files can contain executable source blocks.
  (org-confirm-babel-evaluate t)
  (org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|"
                                "DONE(d!)" "CANCELLED(c@)"))))

(setq org-capture-templates
      '(("t" "Task" entry (file "inbox.org") "* TODO %?\n  %U\n")
        ("r" "Research note" entry (file "research.org") "* %^{Title}\n  %U\n\n%?")
        ("m" "Meeting note" entry (file+headline "research.org" "Meetings")
         "* %^{Meeting}\n  %U\n\n%?")))

(use-package org-modern
  :if (package-installed-p 'org-modern)
  :hook (org-mode . org-modern-mode))

(provide 'init-org)

;;; init-org.el ends here
