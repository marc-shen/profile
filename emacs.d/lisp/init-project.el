;;; init-project.el --- Project management -*- lexical-binding: t; -*-

(require 'init-keymap)

(defvar orderless-smart-case)
(defvar vertico-map)

(declare-function dired-get-filename "dired"
                  (&optional localp no-error-if-not-filep))
(declare-function dired-move-to-filename "dired" (&optional raise-error eol))
(declare-function dired-copy-filename-as-kill "dired" (&optional arg))
(declare-function wdired-change-to-wdired-mode "wdired")

(use-package project
  :ensure nil
  :custom
  (project-switch-commands
   '((project-find-file "Find file" ?f) (consult-ripgrep "Ripgrep" ?g)
     (project-find-dir "Find directory" ?d) (project-eshell "Eshell" ?e)
     (magit-project-status "Magit" ?m) (project-compile "Compile" ?c))))

(defun my-dired-entry-at-point-p ()
  "Return non-nil on a real Dired entry other than `.' or `..'."
  (let ((filename (dired-get-filename nil t)))
    (and filename
         (not (member (file-name-nondirectory filename) '("." ".."))))))

(defun my-dired-first-entry ()
  "Move to the first real file entry in the current Dired buffer."
  (interactive)
  (goto-char (point-min))
  (while (and (not (eobp)) (not (my-dired-entry-at-point-p)))
    (forward-line 1))
  (unless (my-dired-entry-at-point-p)
    (user-error "No file entries in this Dired buffer"))
  (dired-move-to-filename))

(defun my-dired-last-entry ()
  "Move to the last real file entry in the current Dired buffer."
  (interactive)
  (goto-char (point-max))
  (forward-line -1)
  (while (and (not (bobp)) (not (my-dired-entry-at-point-p)))
    (forward-line -1))
  (unless (my-dired-entry-at-point-p)
    (user-error "No file entries in this Dired buffer"))
  (dired-move-to-filename))

(defun my-dired-copy-absolute-path ()
  "Copy absolute paths of the current or marked Dired entries."
  (interactive)
  (dired-copy-filename-as-kill 0))

(defvar-keymap my-dired-goto-map
  :doc "Helix-style goto prefix for Dired."
  "g" #'my-dired-first-entry
  "e" #'my-dired-last-entry
  "r" #'revert-buffer
  "j" #'dired-goto-file
  "y" #'dired-show-file-type)

(use-package dired
  :ensure nil
  :custom
  (dired-kill-when-opening-new-dired-buffer t)
  ;; With two Dired windows on screen, `C' and `R' default to the directory of
  ;; the other one instead of the current one -- the two-pane file manager
  ;; arrangement.  It falls back to the old default whenever no second Dired is
  ;; visible, so nothing changes for a lone window.
  (dired-dwim-target t)
  (dired-use-ls-dired (eq system-type 'gnu/linux))
  (dired-listing-switches
   (if (eq system-type 'gnu/linux)
       "-alh --group-directories-first"
     "-alh"))
  :config
  ;; Dired remains exempt from the Helix minor mode: its mark set already acts
  ;; like a selection, while a direct mode map avoids normal/insert state and
  ;; preserves Dired's file-operation semantics.
  (keymap-set dired-mode-map "h" #'dired-up-directory)
  (keymap-set dired-mode-map "j" #'dired-next-line)
  (keymap-set dired-mode-map "k" #'dired-previous-line)
  (keymap-set dired-mode-map "l" #'dired-find-file)
  (keymap-set dired-mode-map "G" #'my-dired-last-entry)
  (keymap-set dired-mode-map "/" #'dired-isearch-filenames)
  (keymap-set dired-mode-map "g" my-dired-goto-map)

  ;; Treat marks as Helix selections.  Lower-case x selects instead of
  ;; performing a destructive action; upper-case X executes deletion flags.
  ;; The original commands displaced by j/k/y live under g j, K and g y.
  (keymap-set dired-mode-map "x" #'dired-mark)
  (keymap-set dired-mode-map "," #'dired-unmark)
  (keymap-set dired-mode-map "X" #'dired-do-flagged-delete)
  (keymap-set dired-mode-map "y" #'dired-copy-filename-as-kill)
  (keymap-set dired-mode-map "Y" #'my-dired-copy-absolute-path)
  (keymap-set dired-mode-map "r" #'dired-do-rename)
  (keymap-set dired-mode-map "H" #'dired-kill-subdir)
  (keymap-set dired-mode-map "K" #'dired-do-kill-lines)
  (keymap-set dired-mode-map "q" #'wdired-change-to-wdired-mode))
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

(keymap-global-set "C-c z" #'my-zoxide-find-file)
(keymap-global-set "C-c Z" #'my-zoxide-dired)

;; Hand the current file to the desktop's own file manager.  Both back ends
;; take the *file* and select it in its parent directory rather than opening
;; the directory blind, which is what "show me where this is" actually means.
;; Dolphin needs `--select' for that; Finder's equivalent is `open -R'.  The
;; xdg-open fallback has no such option, so it gets the containing directory.
(declare-function dired-get-filename "dired" (&optional localp no-error-if-not-filep))

(defun init-project--reveal-target ()
  "Return the file the file manager should select.
In Dired that is the entry at point, in a file buffer the file itself, and
anywhere else the buffer's `default-directory'."
  (let ((target (or (and (derived-mode-p 'dired-mode) (dired-get-filename nil t))
                    buffer-file-name
                    default-directory)))
    (when (file-remote-p target)
      (user-error "Cannot reveal a remote file in the file manager"))
    (expand-file-name target)))

(defun my-reveal-in-file-manager (&optional arg)
  "Reveal the current file in the system file manager.
A directory is opened rather than selected in its parent, since a window
showing its contents is what the name of a directory asks for.  With a prefix
ARG, open the containing directory instead of selecting the file in it."
  (interactive "P")
  (let* ((target (init-project--reveal-target))
         (directory (or (file-directory-p target) arg))
         (path (if directory
                   (file-name-as-directory
                    (if (file-directory-p target)
                        target
                      (file-name-directory target)))
                 target)))
    (pcase system-type
      ('darwin (if directory
                   (call-process "open" nil 0 nil path)
                 (call-process "open" nil 0 nil "-R" path)))
      (_ (if (and (not directory) (executable-find "dolphin"))
             (call-process "dolphin" nil 0 nil "--select" path)
           (call-process (or (executable-find "dolphin") "xdg-open")
                         nil 0 nil path))))))

;; Parked in `my-override-map' rather than the global map: "show me this file
;; in the file manager" is a question about the buffer, not about its mode, so
;; the key has to survive major modes that claim `C-c o' (Org's `org-open-at-
;; point' menu, Markdown's `C-c C-c o'-style prefixes) and terminal buffers
;; that would otherwise pass the key through to the shell.
(keymap-set my-override-map "C-c o" #'my-reveal-in-file-manager)

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
