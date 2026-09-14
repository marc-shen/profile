;;; init-python.el --- Python development -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'project)
(require 'savehist)
(require 'seq)
(require 'subr-x)

(defgroup init-python nil
  "Python development configuration."
  :group 'languages)

(defcustom init-python-manager-directories
  '("~/.pixi/bin"
    "~/.local/bin"
    "~/.pyenv/bin"
    "~/miniforge3/bin"
    "~/mambaforge/bin"
    "~/miniconda3/bin"
    "~/anaconda3/bin")
  "Fallback directories containing Python environment-manager commands.

GUI and daemon Emacs sessions often do not inherit the login shell's PATH.
These directories are searched without adding them globally to `exec-path',
so finding Conda does not accidentally make its base Python the system Python."
  :type '(repeat directory)
  :group 'init-python)

(defun init-python-manager-executable (program)
  "Find environment-manager PROGRAM, including common per-user locations."
  (or (executable-find program)
      (locate-file program
                   (mapcar #'expand-file-name
                           init-python-manager-directories)
                   exec-suffixes #'file-executable-p)))

(defvar init-python-project-environments nil
  "Alist mapping project roots to explicitly selected Python environments.")
(add-to-list 'savehist-additional-variables
             'init-python-project-environments)

(defvar pet-search-globally)
(declare-function eglot-current-server "eglot")
(declare-function eglot-reconnect "eglot" (server &optional interactive))
(declare-function jsonrpc-running-p "jsonrpc" (connection))
(declare-function pet-buffer-local-vars-setup "pet")
(declare-function pet-buffer-local-vars-teardown "pet")
(declare-function pet--executable-find "pet" (command &optional remote))
(declare-function pet-cache-put "pet" (path value))
(declare-function pet-hatch-environments "pet")
(declare-function pet-mode "pet" (&optional arg))
(declare-function pet-project-root "pet")
(declare-function pet-system-bin-dir "pet")
(declare-function pet-use-hatch-p "pet")
(declare-function pet-virtualenv-root "pet")

(defun init-python--pet-executable-find (original executable
                                                  &optional search-globally)
  "Find EXECUTABLE quickly once Pet has resolved the environment.

Pet's general resolver supports many managers and pre-commit environments, but
`pet-buffer-local-vars-setup' calls it once for every supported Python tool.
Repeating full project discovery for missing tools makes opening a buffer very
slow.  Use the already selected environment directly, retaining Pet's original
resolver only when no environment can be determined."
  (let ((environment
         (or (and (boundp 'python-shell-virtualenv-root)
                  python-shell-virtualenv-root)
             (pet-virtualenv-root))))
    (if (not (stringp environment))
        (funcall original executable search-globally)
      (let* ((bin-directory
              (expand-file-name (pet-system-bin-dir) environment))
             (python-p (string-prefix-p "python" executable))
             (names (if python-p
                        (delete-dups (list executable "python" "python3"))
                      (list executable)))
             (local
              (seq-some
               (lambda (name)
                 (locate-file name (list bin-directory)
                              exec-suffixes #'file-executable-p))
               names)))
        (or local
            (when (or search-globally pet-search-globally)
              (seq-some
               (lambda (name)
                 (pet--executable-find name))
               names)))))))

(defun init-python--pet-eglot-options (original command)
  "Return Pet Eglot options for COMMAND without an invalid Pyright venvPath.

Pet currently sends the selected environment root as `python.venvPath'.
Pyright interprets that setting as a directory *containing* environments and
therefore tries children such as `bin' as though they were environments.  An
absolute `pythonPath' already identifies the interpreter unambiguously."
  (if (seq-some (lambda (part)
                  (and (stringp part)
                       (string-match-p
                        "\\(?:based\\)?pyright-langserver" part)))
                (if (listp command) command (list command)))
      (or (when-let* ((python (pet-executable-find "python")))
            `(:python (:pythonPath ,python)))
          (funcall original command))
    (funcall original command)))

(defun init-python-project-try-python (directory)
  "Return a lightweight project for a Python project above DIRECTORY.

This makes standalone uv, Pixi, and conventional Python projects visible to
`project.el', Pet, and Eglot even when they are not Git repositories."
  (when-let* ((root
               (locate-dominating-file
                directory
                (lambda (parent)
                  (seq-some
                   (lambda (marker)
                     (file-exists-p (expand-file-name marker parent)))
                   '("pyproject.toml" "uv.lock" "pixi.toml"
                     "setup.py" "setup.cfg" "requirements.txt"))))))
    (cons 'init-python-project root)))

(cl-defmethod project-root ((project (head init-python-project)))
  "Return the root directory of Python PROJECT."
  (cdr project))

(defconst init-python-project-ignored-directories
  '(".venv/" "venv/" "env/" ".pixi/" ".tox/" ".nox/"
    "__pycache__/" ".pytest_cache/" ".mypy_cache/" ".ruff_cache/"
    "node_modules/")
  "Generated directories excluded from non-VC Python projects.

Besides making project commands more useful, this is important for Eglot:
language servers commonly request a `**' file watch, and recursively watching
an environment can synchronously traverse tens of thousands of package files
while a newly opened buffer is becoming interactive.")

(cl-defmethod project-ignores ((_project (head init-python-project)) dir)
  "Return ignores for a standalone Python project rooted above DIR."
  (append init-python-project-ignored-directories
          (project-ignores nil dir)))

;; Keep VC projects as the first choice and use Python markers as a fallback.
(add-hook 'project-find-functions #'init-python-project-try-python t)

(defun init-python--project-key (root)
  "Return a stable persistence key for project ROOT."
  (file-name-as-directory (expand-file-name root)))

(defun init-python--preferred-project-environment (root)
  "Return the fast, unambiguous Python environment for ROOT, if any."
  (let* ((key (init-python--project-key root))
         (saved (alist-get key init-python-project-environments
                           nil nil #'equal))
         (pixi-default (cdr (assoc "default"
                                   (init-python-pixi-environments root))))
         (local
          (cl-loop for name in '(".venv" "venv" "env")
                   for environment = (expand-file-name name root)
                   when (and (file-directory-p environment)
                             (init-python--environment-python environment))
                   return environment))
         (active (or (getenv "VIRTUAL_ENV") (getenv "CONDA_PREFIX"))))
    (cl-loop for environment in (list saved pixi-default local active)
             when (and (stringp environment)
                       (file-directory-p environment)
                       (init-python--environment-python environment))
             return environment)))

(defun init-python-restore-project-environment ()
  "Restore this project's saved Python environment before Pet initializes."
  (when (require 'pet nil t)
    (when-let* ((root (pet-project-root))
                (key (init-python--project-key root))
                (environment
                 (init-python--preferred-project-environment root)))
      (pet-cache-put (list root :virtualenv) environment)
      ;; Do not keep selecting a deleted environment on future startups.
      (when-let* ((saved (alist-get key init-python-project-environments
                                    nil nil #'equal)))
        (unless (file-directory-p saved)
          (setf (alist-get key init-python-project-environments
                           nil 'remove #'equal)
                nil))))))

(defun my-jupytext--run (&rest arguments)
  "Run Jupytext on the current file with ARGUMENTS.

Save the current buffer first, then reload it after a successful conversion so
the text shown by Emacs agrees with the file Jupytext may have updated."
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file"))
  (unless (executable-find "jupytext")
    (user-error
     "Jupytext is not on PATH; install it with `uv tool install jupytext`"))
  (when (buffer-modified-p)
    (save-buffer))
  (let ((output (get-buffer-create "*Jupytext*"))
        (file buffer-file-name))
    (with-current-buffer output
      (erase-buffer))
    (let ((exit-code (apply #'process-file "jupytext" nil output nil
                            (append arguments (list file)))))
      (if (equal exit-code 0)
          (progn
            (revert-buffer :ignore-auto :noconfirm)
            (message "Jupytext updated %s" (file-name-nondirectory file)))
        (display-buffer output)
        (user-error "Jupytext failed with exit code %s" exit-code)))))

(defun my-jupytext-pair-notebook ()
  "Pair the current notebook with a Python percent-format script.

The resulting `.ipynb' keeps outputs while the `.py' file is pleasant to edit
and review.  Run `my-jupytext-sync' after editing either representation."
  (interactive)
  (my-jupytext--run "--set-formats" "ipynb,py:percent"))

(defun my-jupytext-sync ()
  "Synchronize all Jupytext representations paired with the current file."
  (interactive)
  (my-jupytext--run "--sync"))

(use-package python
  :ensure nil
  ;; `major-mode-remap-alist' promotes these to `python-ts-mode' when its
  ;; grammar is present and leaves them usable as `python-mode' beforehand.
  :mode ("\\.py\\'" . python-mode)
  :interpreter (("python" . python-mode)
                ("python3" . python-mode))
  :custom
  (python-indent-offset 4)
  (python-shell-interpreter "python")
  :bind (:map python-mode-map
              ("C-c C-c" . python-shell-send-buffer)
              ("C-c C-r" . python-shell-send-region)
              ("C-c C-z" . python-shell-switch-to-shell)))

;; Pet resolves the project's virtualenv.  It has to run before `eglot-ensure',
;; otherwise Pyright indexes the global interpreter and cannot complete any
;; third-party import.  The negative depth keeps it ahead of the Eglot hook.
(use-package pet
  :if (package-installed-p 'pet)
  :init
  (add-hook 'python-mode-hook #'init-python-restore-project-environment -20)
  (add-hook 'python-ts-mode-hook #'init-python-restore-project-environment -20)
  (add-hook 'python-mode-hook #'pet-mode -10)
  (add-hook 'python-ts-mode-hook #'pet-mode -10)
  :config
  (advice-add 'pet-executable-find
              :around #'init-python--pet-executable-find)
  (advice-add 'pet-lookup-eglot-server-initialization-options
              :around #'init-python--pet-eglot-options)
  ;; Show the selected interpreter environment instead of the generic "Pet".
  ;; `python-shell-virtualenv-root' is buffer-local and already maintained by
  ;; Pet, so this adds no environment discovery work during redisplay.
  (when-let* ((entry (assq 'pet-mode minor-mode-alist)))
    (setf (cadr entry) '(:eval (init-python-environment-lighter)))))

(defun init-python-environment-lighter ()
  "Return a compact mode-line label for the current Python environment."
  (format " Py[%s]"
          (if (and (boundp 'python-shell-virtualenv-root)
                   python-shell-virtualenv-root)
              (file-name-nondirectory
               (directory-file-name python-shell-virtualenv-root))
            "system")))

(defun init-python--json-command (program &rest arguments)
  "Run PROGRAM with ARGUMENTS and parse its JSON output.

Return nil when the command fails or its output is not valid JSON.  Environment
discovery is best-effort: one broken manager must not prevent other managers
from contributing candidates."
  (when program
    (with-temp-buffer
      (when (equal 0 (apply #'process-file program nil t nil arguments))
        (condition-case nil
            (json-parse-string (buffer-string)
                               :object-type 'alist
                               :array-type 'list
                               :null-object nil
                               :false-object nil)
          (error nil))))))

(defun init-python--command-line (program &rest arguments)
  "Return the first trimmed output line from PROGRAM with ARGUMENTS."
  (when program
    (with-temp-buffer
      (when (equal 0 (apply #'process-file program nil t nil arguments))
        (goto-char (point-min))
        (string-trim (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position)))))))

(defun init-python--environment-python (environment)
  "Return ENVIRONMENT's Python executable, or nil if it has none."
  (let ((bin-directory
         (expand-file-name (pet-system-bin-dir) environment)))
    (or (locate-file "python" (list bin-directory)
                     exec-suffixes #'file-executable-p)
        (locate-file "python3" (list bin-directory)
                     exec-suffixes #'file-executable-p))))

(defun init-python--pixi-project-root (&optional directory)
  "Return the Pixi workspace above DIRECTORY, or nil.

Recognize both `pixi.toml' workspaces and Pixi configuration embedded in
`pyproject.toml'.  This deliberately does not ask Pet to parse TOML: Pixi can
describe its own workspace as JSON, and Pet's TOML parser is optional."
  (locate-dominating-file
   (or directory default-directory)
   (lambda (parent)
     (or (file-exists-p (expand-file-name "pixi.toml" parent))
         (file-exists-p (expand-file-name "pixi.lock" parent))
         (let ((pyproject (expand-file-name "pyproject.toml" parent)))
           (and (file-readable-p pyproject)
                (with-temp-buffer
                  (insert-file-contents pyproject)
                  (re-search-forward
                   "^[[:space:]]*\\[tool\\.pixi\\(?:\\.\\|\\]\\)" nil t))))))))

(defun init-python-pixi-environments (&optional directory)
  "Return Pixi environments above DIRECTORY as (NAME . PREFIX) pairs.

Both values come directly from `pixi info --json'.  In particular, do not
infer NAME from PREFIX's basename: detached environment storage does not
guarantee that those strings are equal."
  (when-let* ((pixi (init-python-manager-executable "pixi"))
              (root (init-python--pixi-project-root directory)))
    (let* ((default-directory root)
           (info (init-python--json-command pixi "info" "--json"))
           (environments (alist-get 'environments_info info)))
      (delq nil
            (mapcar
             (lambda (environment)
               (when-let* ((name (alist-get 'name environment))
                           (prefix (alist-get 'prefix environment)))
                 (cons name
                       (directory-file-name (expand-file-name prefix)))))
             environments)))))

(defun init-python--environment-candidates ()
  "Return local and machine-wide Python environment choices.

Each result is a (DISPLAY . DIRECTORY) pair.  Environment managers capable of
listing multiple environments contribute every installed choice; Pet's
automatically detected environment covers Poetry and Pipenv too."
  (let* ((root (pet-project-root))
         (uv-project (and root
                          (file-exists-p (expand-file-name "uv.lock" root))))
         (conda (init-python-manager-executable "conda"))
         (mamba (or (init-python-manager-executable "mamba")
                    (init-python-manager-executable "micromamba")))
         (pyenv (init-python-manager-executable "pyenv"))
         candidates paths)
    (cl-labels
        ((add-environment
          (source path &optional include-uninstalled display-name)
          (when (stringp path)
            (let* ((expanded (directory-file-name (expand-file-name path)))
                   (installed (and (file-directory-p expanded)
                                   (init-python--environment-python expanded))))
              (when (or installed include-uninstalled)
                (unless (member expanded paths)
                  (push expanded paths)
                  (push (cons (format "%s: %s (%s)%s"
                                      source
                                      (or display-name
                                          (file-name-nondirectory expanded))
                                      (abbreviate-file-name expanded)
                                      (if installed "" " [not installed]"))
                              expanded)
                        candidates))))))
         (add-children
          (source parent)
          (when (and (stringp parent) (file-directory-p parent))
            (dolist (path (directory-files parent t directory-files-no-dot-files-regexp))
              (when (file-directory-p path)
                (add-environment source path))))))
      ;; Project-local managers and conventional virtualenv directories.
      (dolist (environment (init-python-pixi-environments root))
        ;; Pixi can install a declared environment lazily.  Keep uninstalled
        ;; choices visible, but distinguish them from usable interpreters.
        (add-environment "pixi" (cdr environment) t (car environment)))
      (dolist (provider '(("hatch" pet-use-hatch-p pet-hatch-environments)))
        (when (ignore-errors (funcall (nth 1 provider)))
          (dolist (environment (or (ignore-errors (funcall (nth 2 provider)))
                                   nil))
            (add-environment (car provider) environment))))
      (when root
        ;; Also find top-level environments with non-conventional names.
        (add-children "local venv" root)
        (dolist (name '(".venv" "venv" "env"))
          (let ((environment (expand-file-name name root)))
            (when (file-directory-p environment)
              (add-environment (if uv-project "uv" "project venv")
                               environment)))))
      (when-let* ((detected (ignore-errors (pet-virtualenv-root))))
        (add-environment "detected" detected))
      (when-let* ((active (or (getenv "VIRTUAL_ENV")
                              (getenv "CONDA_PREFIX"))))
        (add-environment "active" active))
      (add-environment "global venv" (expand-file-name "~/.venv"))

      ;; Conda and Mamba keep global registries, so query them even when the
      ;; current project has no environment.yml.
      (when-let* ((info (init-python--json-command conda "info" "--json")))
        (when-let* ((base (alist-get 'root_prefix info)))
          (add-environment "conda base" base))
        (dolist (environment (alist-get 'envs info))
          (add-environment "conda" environment)))
      (when-let* ((info (init-python--json-command mamba "info" "--envs" "--json")))
        (when-let* ((base (alist-get 'root_prefix info)))
          (add-environment "mamba base" base))
        (dolist (environment (alist-get 'envs info))
          (add-environment "mamba" environment)))

      ;; pyenv installations are environments in their own right.  Scanning
      ;; its versions directory also includes virtualenvs made by
      ;; pyenv-virtualenv without spawning one process per version.
      (when-let* ((pyenv-root (init-python--command-line pyenv "root")))
        (add-children "pyenv" (expand-file-name "versions" pyenv-root)))

      ;; virtualenvwrapper and common hand-managed global venv locations.
      (dolist (parent (delete-dups
                       (delq nil
                             (list (getenv "WORKON_HOME")
                                   (expand-file-name "~/.virtualenvs")
                                   (expand-file-name "~/.venvs")
                                   (expand-file-name "~/.local/share/virtualenvs")))))
        (add-children "global venv" parent))
      (nreverse candidates))))

(defun init-python--project-buffers (root)
  "Return Python buffers visiting files below ROOT."
  (cl-loop for buffer in (buffer-list)
           when (with-current-buffer buffer
                  (and buffer-file-name
                       (string-prefix-p root (expand-file-name buffer-file-name))
                       (derived-mode-p 'python-base-mode 'python-mode)))
           collect buffer))

(defun my-python-select-environment (&optional choose-directory)
  "Select the Python environment for the current project.

Normally choose among project-local and machine-wide environments discovered
from uv, Pixi, Conda/Mamba, Hatch, pyenv, and conventional venv directories.
With prefix argument CHOOSE-DIRECTORY, select an arbitrary environment
directory.  Refresh all Python buffers in the project and reconnect their
Eglot servers.  Existing Python shells and marimo kernels must be restarted
separately."
  (interactive "P")
  (unless (require 'pet nil t)
    (user-error "Pet is not installed; run M-x my-install-packages"))
  (let* ((root (or (pet-project-root)
                   (user-error "No Python project was found here")))
         (candidates (unless choose-directory
                       (init-python--environment-candidates)))
         (environment
          (directory-file-name
           (expand-file-name
            (if candidates
                (alist-get (completing-read "Python environment: "
                                             candidates nil t)
                           candidates nil nil #'string-equal)
              (read-directory-name "Python environment directory: "
                                   root nil t)))))
         (python (init-python--environment-python environment))
         (pixi-environment
          (cl-find-if
           (lambda (candidate)
             (equal environment (cdr candidate)))
           (init-python-pixi-environments root)))
         (buffers (init-python--project-buffers root))
         (servers
          (delete-dups
           (delq nil
                 (mapcar
                  (lambda (buffer)
                    (with-current-buffer buffer
                      (and (fboundp 'eglot-current-server)
                           (ignore-errors (eglot-current-server)))))
                  buffers)))))
    (unless python
      (if pixi-environment
          (user-error
           (concat "Pixi environment %s is not installed; run `pixi install "
                   "--environment %s`, then select it again")
           (car pixi-environment) (car pixi-environment))
        (user-error "%s does not contain an executable Python" environment)))
    (pet-cache-put (list root :virtualenv) environment)
    (setf (alist-get (init-python--project-key root)
                     init-python-project-environments nil nil #'equal)
          environment)
    (savehist-save)
    (dolist (buffer buffers)
      (with-current-buffer buffer
        (when (bound-and-true-p pet-mode)
          ;; Some Python buffers may intentionally be read-only.  Pet only
          ;; refreshes buffer-local tool variables here, so allow hooks to run
          ;; without turning an incidental text property into a switch error.
          (let ((inhibit-read-only t))
            (with-silent-modifications
              (pet-buffer-local-vars-teardown)
              (pet-buffer-local-vars-setup))))))
    (dolist (server servers)
      (when (and (fboundp 'eglot-reconnect)
                 (jsonrpc-running-p server))
        (eglot-reconnect server)))
    (message (concat "Python environment: %s. Eglot refreshed; restart any "
                     "running Python shell or marimo server to switch its kernel.")
             (abbreviate-file-name environment))))

(keymap-global-set "C-c p" #'my-python-select-environment)
(use-package reformatter
  :if (package-installed-p 'reformatter)
  :config
  (reformatter-define ruff-format
    :program "ruff" :args '("format" "-") :group 'init-python)
  (reformatter-define black-format
    :program "black" :args '("-") :group 'init-python))
(use-package csv-mode
  :if (package-installed-p 'csv-mode)
  :mode "\\.csv\\'")

;; A percent-format script remains ordinary Python -- Eglot, formatters and
;; Git all see readable text -- while `code-cells-mode' adds notebook-style
;; navigation and evaluation.  `code-cells-mode-maybe' deliberately leaves
;; normal Python files alone.  Opening an ipynb file directly is also supported
;; through Jupytext, but paired files are preferable because their ipynb side
;; retains rich outputs.
(use-package code-cells
  :if (package-installed-p 'code-cells)
  :commands (code-cells-mode-maybe code-cells-convert-ipynb
             code-cells-write-ipynb)
  :hook ((python-mode . code-cells-mode-maybe)
         (python-ts-mode . code-cells-mode-maybe))
  :bind (:map code-cells-mode-map
              ("C-c C-c" . code-cells-eval)
              ("C-c % j" . my-jupytext-sync)))

(provide 'init-python)

;;; init-python.el ends here
