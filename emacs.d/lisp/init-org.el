;;; init-org.el --- Org mode configuration -*- lexical-binding: t; -*-

(use-package org
  :ensure nil
  :hook ((org-mode . visual-line-mode) (org-mode . variable-pitch-mode))
  :bind (("C-c a" . org-agenda) ("C-c n" . org-capture))
  :custom
  (org-directory "~/Documents/org")
  (org-default-notes-file (expand-file-name "notes.org" org-directory))
  ;; One file per kind of content: tasks.org holds TODO items, calendar.org
  ;; holds dated events, notes.org holds everything without a state or a date.
  (org-agenda-files (list (expand-file-name "tasks.org" org-directory)
                          (expand-file-name "calendar.org" org-directory)
                          (expand-file-name "notes.org" org-directory)))
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

;; `%^T' prompts for an active timestamp through the calendar picker, which is
;; what puts an event on the agenda's time grid.  Tasks deliberately capture
;; without a date: scheduling them is a separate decision made later with
;; `C-c C-s' / `C-c C-d'.
(setq org-capture-templates
      '(("t" "Task" entry (file "tasks.org") "* TODO %?\n  %U\n")
        ("e" "Event" entry (file "calendar.org") "* %^{Event}\n  %^T\n\n%?")
        ("n" "Note" entry (file "notes.org") "* %^{Title}\n  %U\n\n%?")
        ("m" "Meeting note" entry (file+headline "notes.org" "Meetings")
         "* %^{Meeting}\n  %U\n\n%?")))

(use-package org-modern
  :if (package-installed-p 'org-modern)
  :hook (org-mode . org-modern-mode))

(provide 'init-org)

;;; init-org.el ends here
