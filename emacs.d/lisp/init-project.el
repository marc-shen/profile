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
  :custom
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-use-ls-dired (eq system-type 'gnu/linux))
  (dired-listing-switches
   (if (eq system-type 'gnu/linux)
       "-alh --group-directories-first"
     "-alh")))
(use-package dired-subtree
  :if (package-installed-p 'dired-subtree)
  :after dired
  :bind (:map dired-mode-map ("TAB" . dired-subtree-toggle)))
(use-package treemacs
  :if (package-installed-p 'treemacs)
  :defer t
  :bind (("C-c t" . treemacs)))

;; Zoxide ranks directories by how often and how recently they are entered.
;; Reusing that database means a directory visited from the shell is already
;; one fuzzy match away in Emacs, without maintaining a second bookmark list.
(use-package zoxide
  :if (and (package-installed-p 'zoxide) (executable-find "zoxide"))
  :commands (zoxide-add zoxide-query)
  :init
  ;; Feed the database from Emacs too, otherwise only directories entered from
  ;; the shell ever gain a score.  Called from a hook rather than
  ;; interactively, `zoxide-add' takes the path from `default-directory'.
  (add-hook 'find-file-hook #'zoxide-add)
  (add-hook 'dired-mode-hook #'zoxide-add))

(defun init-project-zoxide-directories ()
  "Return the zoxide database as a list of directories, best match first.
Entries whose directory has since been deleted are dropped; remote names are
skipped because probing them would block on the network."
  (when (and (executable-find "zoxide") (require 'zoxide nil t))
    (let (directories)
      (dolist (directory (zoxide-query) (nreverse directories))
        (when (and (not (file-remote-p directory))
                   (file-directory-p directory))
          (push (abbreviate-file-name (file-name-as-directory directory))
                directories))))))

;; Directory names capitalize irregularly -- EMPi, GitHub, Downloads -- while
;; `orderless-smart-case' turns matching case-sensitive as soon as the input
;; holds one upper-case letter, so "Empi" matches nothing at all.  On a
;; case-insensitive filesystem the distinction buys nothing for a path, so drop
;; it at these prompts while leaving the smart behaviour for code identifiers.
(defun init-project-completion-ignoring-case (function &rest arguments)
  "Apply FUNCTION to ARGUMENTS with case-insensitive candidate matching."
  (let ((completion-ignore-case t)
        (orderless-smart-case nil))
    (apply function arguments)))

(defun init-project-zoxide-read-directory (prompt)
  "Read a directory from the zoxide database, prompting with PROMPT.
The table reports `identity' as its sort function: the ranking is the whole
point of zoxide, and Vertico would otherwise re-sort the candidates."
  (let ((directories (init-project-zoxide-directories)))
    (unless directories
      (user-error "The zoxide database has no usable entry"))
    (init-project-completion-ignoring-case
     #'completing-read
     prompt
     (lambda (string predicate action)
       (if (eq action 'metadata)
           '(metadata (category . file)
                      (display-sort-function . identity)
                      (cycle-sort-function . identity))
         (complete-with-action action directories string predicate)))
     nil t)))

(defun my-zoxide-find-file ()
  "Jump to a zoxide directory and open a file inside it."
  (interactive)
  (let ((default-directory (init-project-zoxide-read-directory "Zoxide find file in: ")))
    (call-interactively #'find-file)))

(defun my-zoxide-dired ()
  "Open a zoxide directory in Dired."
  (interactive)
  (dired (init-project-zoxide-read-directory "Zoxide dired: ")))

(global-set-key (kbd "C-c z") #'my-zoxide-find-file)
(global-set-key (kbd "C-c Z") #'my-zoxide-dired)

;; `consult-dir' rewrites the directory part of a file prompt, so the same jump
;; list is reachable from inside `C-x C-f' and `C-x d' instead of only from a
;; separate command.  `C-x C-d' replaces `list-directory', which Dired covers.
;; No `:after consult' here: Consult itself is loaded lazily by its own key
;; bindings, so waiting for it would leave these keys unbound.  Consult-dir
;; pulls Consult in when one of them autoloads it.
(use-package consult-dir
  :if (package-installed-p 'consult-dir)
  :bind (("C-x C-d" . consult-dir)
         :map vertico-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file))
  :config
  (defvar init-project--consult-dir-source-zoxide
    `( :name "Zoxide"
       :narrow ?z
       :category file
       :face consult-file
       :history file-name-history
       :enabled ,(lambda () (and (executable-find "zoxide")
                                 (require 'zoxide nil t)))
       :items ,#'init-project-zoxide-directories)
    "Zoxide directory source for `consult-dir'.")
  ;; Placed first so its ranking leads the candidate list;
  ;; `consult-dir-sort-candidates' is nil, so every source keeps its own order.
  (add-to-list 'consult-dir-sources 'init-project--consult-dir-source-zoxide)
  (advice-add 'consult-dir :around #'init-project-completion-ignoring-case)
  ;; Search the chosen directory with fd rather than find: it is faster, obeys
  ;; .gitignore, and matches case-insensitively until the pattern says otherwise.
  (setq consult-dir-jump-file-command #'consult-fd))

(provide 'init-project)

;;; init-project.el ends here
