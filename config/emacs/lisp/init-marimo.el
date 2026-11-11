;;; init-marimo.el --- marimo notebooks from Emacs -*- lexical-binding: t; -*-

(require 'ansi-color)
(require 'browse-url)
(require 'cl-lib)

(defvar pet-search-globally)
(declare-function init-python--pixi-project-root "init-python" (&optional directory))
(declare-function init-python-manager-executable "init-python" (program))
(declare-function init-python-pixi-environments "init-python" (&optional directory))
(declare-function pet-executable-find "pet" (executable &optional search-globally))
(declare-function pet-virtualenv-root "pet")
(declare-function yas-expand-snippet "yasnippet" (snippet &optional start end expand-env))

(defgroup init-marimo nil
  "Run marimo notebooks while editing their Python source in Emacs."
  :group 'python)

(defcustom init-marimo-edit-arguments '("--headless" "--watch")
  "Arguments appended to `marimo edit'.

`--watch' streams files saved by Emacs into marimo.  `--headless' prevents
marimo from opening a second browser; Emacs opens the URL after the server has
printed it.  Keep marimo's default token authentication enabled, even though
the server listens only on localhost."
  :type '(repeat string)
  :group 'init-marimo)

(defcustom init-marimo-browser-function #'browse-url-default-browser
  "Function used to open a marimo editor URL.

The default always uses the operating system's browser.  This deliberately
bypasses the global `browse-url-browser-function', which this configuration may
set to embr for ordinary links: marimo is a large interactive web application
and works better in a native browser."
  :type 'function
  :group 'init-marimo)

(defcustom init-marimo-notebook-file-regexp "_mo\\.py\\'"
  "File-name regexp that explicitly marks a Python file as a marimo notebook.

The suffix is only a convenient convention.  Ordinary `.py' notebooks are
also recognized from their generated marimo structure."
  :type 'regexp
  :group 'init-marimo)

(defcustom init-marimo-detection-limit (* 16 1024)
  "Maximum number of characters scanned when detecting a marimo notebook."
  :type 'integer
  :group 'init-marimo)

(define-minor-mode init-marimo-notebook-mode
  "Mark the current Python buffer as a marimo notebook."
  :lighter " Mo"
  :group 'init-marimo)

(defun init-marimo--regexp-p (regexp)
  "Return non-nil when REGEXP occurs in the narrowed detection region."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward regexp nil t)))

(defun init-marimo-notebook-p ()
  "Return non-nil when the current buffer is a marimo Python notebook.

An `_mo.py' suffix is an immediate positive match.  Otherwise inspect only the
start of the buffer and require generated marimo structure, not merely an
`import marimo' statement that could occur in an ordinary application."
  (and (derived-mode-p 'python-base-mode 'python-mode)
       (or (and buffer-file-name
                (string-match-p init-marimo-notebook-file-regexp
                                (file-name-nondirectory buffer-file-name)))
           (save-restriction
             (widen)
             (narrow-to-region
              (point-min)
              (min (point-max)
                   (+ (point-min) init-marimo-detection-limit)))
             (and (init-marimo--regexp-p
                   "^[[:space:]]*app[[:space:]]*=[[:space:]]*marimo\\.App\\_>")
                  (or (init-marimo--regexp-p
                       "^[[:space:]]*__generated_with[[:space:]]*=")
                      (init-marimo--regexp-p
                       "^[[:space:]]*@app\\.cell\\_>")
                      (init-marimo--regexp-p
                       "^[[:space:]]*app\\.run[[:space:]]*(")))))))

(defun init-marimo-detect-notebook ()
  "Enable `init-marimo-notebook-mode' when this buffer is a notebook."
  (init-marimo-notebook-mode (if (init-marimo-notebook-p) 1 -1))
  (add-hook 'after-save-hook #'init-marimo-detect-notebook nil t))

(add-hook 'python-mode-hook #'init-marimo-detect-notebook)
(add-hook 'python-ts-mode-hook #'init-marimo-detect-notebook)

(defun init-marimo--ensure-notebook ()
  "Signal a user error unless the current buffer is a marimo notebook."
  (unless (or init-marimo-notebook-mode (init-marimo-notebook-p))
    (user-error
     "This is not recognized as marimo; use an _mo.py name or add marimo.App cells"))
  (init-marimo-notebook-mode 1))

(defun init-marimo--prepare-cell-insertion ()
  "Move to a clean line boundary and leave one blank line before a new cell."
  (unless (bolp)
    (end-of-line)
    (insert "\n"))
  (unless (or (bobp) (looking-back "\n\n" nil))
    (insert "\n")))

(defun init-marimo--wrap-region-as-cell (begin end)
  "Wrap the region from BEGIN to END in a marimo code cell."
  (let ((code (buffer-substring-no-properties begin end)))
    (delete-region begin end)
    (goto-char begin)
    (init-marimo--prepare-cell-insertion)
    (insert "@app.cell\ndef _():\n")
    (let ((body-start (point)))
      (insert code)
      (unless (bolp) (insert "\n"))
      (indent-rigidly body-start (point) 4))
    (insert "    return\n\n")))

(defun my-marimo-insert-cell ()
  "Insert a complete marimo Python cell template at point.

When the region is active, wrap it as the cell body.  Otherwise use Yasnippet
fields when available: TAB moves through arguments, body, and return value."
  (interactive)
  (init-marimo--ensure-notebook)
  (if (use-region-p)
      (init-marimo--wrap-region-as-cell (region-beginning) (region-end))
    (init-marimo--prepare-cell-insertion)
    (if (and (bound-and-true-p yas-minor-mode)
             (fboundp 'yas-expand-snippet))
        (yas-expand-snippet
         "@app.cell\ndef _(${1}):\n    ${2:# code}\n    return ${0}\n\n")
      (insert "@app.cell\ndef _():\n    \n    return\n\n")
      (forward-line -3)
      (end-of-line))))

(defun my-marimo-insert-markdown-cell ()
  "Insert a marimo Markdown cell template at point."
  (interactive)
  (init-marimo--ensure-notebook)
  (init-marimo--prepare-cell-insertion)
  (if (and (bound-and-true-p yas-minor-mode)
           (fboundp 'yas-expand-snippet))
      (yas-expand-snippet
       (concat "@app.cell\ndef _(mo):\n    mo.md(\n        r\"\"\"\n"
               "        ${1:# Markdown}\n        \"\"\"\n    )\n"
               "    return ${0}\n\n"))
    (insert (concat "@app.cell\ndef _(mo):\n    mo.md(\n        r\"\"\"\n"
                    "        \n        \"\"\"\n    )\n    return\n\n"))
    (forward-line -5)
    (end-of-line)))

(defvar init-marimo--processes (make-hash-table :test #'equal)
  "Map absolute notebook names to their live marimo server processes.")

(defun init-marimo--file-key (file)
  "Return the stable process-table key for FILE."
  (expand-file-name file))

(defun init-marimo--project-root (directory)
  "Find the Python project above DIRECTORY, if any."
  (or (init-python--pixi-project-root directory)
      (locate-dominating-file directory "uv.lock")
      (locate-dominating-file directory "pyproject.toml")))

(defun init-marimo--command (directory)
  "Return a command prefix that runs marimo for DIRECTORY.

Prefer the Python environment Pet selected for the project, then uv's project
runner, and finally a globally installed marimo.  This normally keeps the
notebook kernel, Python shell, and Eglot pointed at the same dependencies."
  (let* ((root (init-marimo--project-root directory))
         (venv-marimo (and root
                            (expand-file-name ".venv/bin/marimo" root)))
         ;; Pet understands Poetry, Pixi, Conda, Hatch, Pipenv, `.venv', and
         ;; pyenv.  Suppress its global fallback here so the next branches can
         ;; distinguish a project executable from a globally installed tool.
         (pet-available (and root (require 'pet nil t)))
         (pet-environment
          (when pet-available
            (let ((default-directory directory))
              (pet-virtualenv-root))))
         (pet-marimo
          (when pet-available
            (let ((default-directory directory)
                  (pet-search-globally nil))
              (pet-executable-find "marimo"))))
         (pixi-environments
          (and root (init-python-pixi-environments directory)))
         (pixi-entry
          (and pet-environment
               (cl-find-if
                (lambda (environment)
                  (equal (directory-file-name
                          (expand-file-name pet-environment))
                         (cdr environment)))
                pixi-environments)))
         (pixi-environment (car-safe pixi-entry))
         (pixi (and pixi-environment
                    (init-python-manager-executable "pixi")))
         (uv (executable-find "uv"))
         (marimo (executable-find "marimo")))
    (cond
     ;; `pixi run' applies activation variables in addition to choosing the
     ;; interpreter, which invoking `.pixi/envs/NAME/bin/marimo' would omit.
     (pixi-environment
      (list pixi "run" "--environment" pixi-environment "marimo"))
     (pet-marimo (list pet-marimo))
     ;; Retained for installations where Pet is optional.
     ((and venv-marimo (file-executable-p venv-marimo))
      (list venv-marimo))
     ((and root uv (file-exists-p (expand-file-name "uv.lock" root)))
      (list uv "run" "marimo"))
     (pet-environment
      (user-error
       "Selected Python environment lacks marimo: %s; install marimo there first"
       (abbreviate-file-name pet-environment)))
     (marimo (list marimo))
     ((and root uv) (list uv "run" "marimo"))
     (t
      (user-error
       "marimo is unavailable; run M-x my-marimo-setup or add it to the project")))))

(defun init-marimo--notebook-file (&optional prompt)
  "Return the current notebook file, prompting when PROMPT or necessary."
  (let ((file (if (and buffer-file-name (not prompt))
                  buffer-file-name
                (read-file-name "marimo notebook: " nil nil nil "notebook.py"))))
    (unless (member (downcase (or (file-name-extension file) "")) '("py" "md"))
      (user-error "A marimo notebook must be a .py or .md file"))
    (expand-file-name file)))

(defun init-marimo--create-empty-notebook (file)
  "Create a minimal, valid marimo notebook at FILE."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (if (string-equal (downcase (or (file-name-extension file) "")) "md")
        (insert "# Notebook\n\n"
                "```python {.marimo}\n"
                "import marimo as mo\n"
                "```\n")
      (insert "import marimo\n\n"
              "app = marimo.App()\n\n"
              "if __name__ == \"__main__\":\n"
              "    app.run()\n"))))

(defun init-marimo--insert-output (process output)
  "Insert OUTPUT from PROCESS into its log buffer."
  (when-let* ((buffer (process-buffer process)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)
            (moving (= (point) (point-max))))
        (goto-char (point-max))
        (insert (ansi-color-filter-apply output))
        (when moving
          (goto-char (point-max)))))))

(defun init-marimo--process-filter (process output)
  "Record PROCESS OUTPUT and open the first localhost URL it contains."
  (init-marimo--insert-output process output)
  (let* ((pending (concat (or (process-get process 'url-tail) "") output))
         (regexp "https?://\\(?:127\\.0\\.0\\.1\\|localhost\\|\\[::1\\]\\):[0-9]+[^ \t\r\n\e]*"))
    (process-put process 'url-tail
                 (substring pending (max 0 (- (length pending) 2048))))
    (when (and (not (process-get process 'url))
               (string-match regexp pending))
      (let ((url (match-string 0 pending)))
        (process-put process 'url url)
        ;; Leave the process filter quickly; opening a native browser can block.
        (run-at-time
         0 nil
         (lambda (server address)
           (when (process-live-p server)
             (funcall init-marimo-browser-function address)))
         process url)))))

(defun init-marimo--process-sentinel (process event)
  "Clean up PROCESS after marimo exits and append EVENT to its log."
  (init-marimo--insert-output process (format "\nmarimo %s" event))
  (unless (process-live-p process)
    (let ((file (process-get process 'notebook)))
      (when (eq process (gethash file init-marimo--processes))
        (remhash file init-marimo--processes)))
    (message "marimo server stopped: %s"
             (file-name-nondirectory (process-get process 'notebook)))))

(defun init-marimo--live-processes ()
  "Return all live marimo processes known to this Emacs session."
  (let (processes stale)
    (maphash (lambda (file process)
               (if (process-live-p process)
                   (push process processes)
                 (push file stale)))
             init-marimo--processes)
    (dolist (file stale)
      (remhash file init-marimo--processes))
    processes))

(defun init-marimo--read-process ()
  "Choose a running marimo server, preferring the current notebook."
  (let* ((current (and buffer-file-name
                       (gethash (init-marimo--file-key buffer-file-name)
                                init-marimo--processes)))
         (processes (init-marimo--live-processes)))
    (cond
     ((and current (process-live-p current)) current)
     ((null processes) (user-error "No marimo server is running"))
     ((null (cdr processes)) (car processes))
     (t
      (let* ((files (mapcar (lambda (process)
                              (process-get process 'notebook))
                            processes))
             (file (completing-read "marimo server: " files nil t)))
        (gethash file init-marimo--processes))))))

(defun my-marimo-edit (&optional prompt)
  "Edit the current notebook with Emacs and a watched marimo server.

With prefix argument PROMPT, choose another `.py' or `.md' file.  A missing
file is initialized as an empty Python-format notebook.  Saving in Emacs sends
the new source to marimo; marimo marks affected cells stale by default."
  (interactive "P")
  (let* ((file (init-marimo--notebook-file prompt))
         (key (init-marimo--file-key file))
         (existing (gethash key init-marimo--processes)))
    (when (and (buffer-file-name) (file-equal-p buffer-file-name file)
               (buffer-modified-p))
      (save-buffer))
    (unless (file-exists-p file)
      (init-marimo--create-empty-notebook file)
      (find-file file))
    (if (and existing (process-live-p existing))
        (if-let* ((url (process-get existing 'url)))
            (funcall init-marimo-browser-function url)
          (pop-to-buffer (process-buffer existing)))
      (let* ((default-directory (file-name-directory file))
             (command (append (init-marimo--command default-directory)
                              (list "edit" file)
                              init-marimo-edit-arguments))
             (tag (substring (secure-hash 'sha1 key) 0 10))
             (buffer (get-buffer-create
                      (format "*marimo: %s [%s]*"
                              (file-name-nondirectory file) tag))))
        (with-current-buffer buffer
          (setq default-directory (file-name-directory file))
          (let ((inhibit-read-only t))
            (erase-buffer))
          (compilation-mode))
        (let ((process (make-process
                        :name (format "marimo-%s" tag)
                        :buffer buffer
                        :command command
                        :noquery t
                        :connection-type 'pipe
                        :filter #'init-marimo--process-filter
                        :sentinel #'init-marimo--process-sentinel)))
          (process-put process 'notebook key)
          (puthash key process init-marimo--processes)
          (message "Starting marimo for %s..."
                   (file-name-nondirectory file)))))))

(defun my-marimo-open ()
  "Open the browser page for a running marimo server."
  (interactive)
  (let ((process (init-marimo--read-process)))
    (if-let* ((url (process-get process 'url)))
        (funcall init-marimo-browser-function url)
      (pop-to-buffer (process-buffer process))
      (message "marimo is still starting; its URL is not available yet"))))

(defun my-marimo-log ()
  "Show the log of a running marimo server."
  (interactive)
  (pop-to-buffer (process-buffer (init-marimo--read-process))))

(defun my-marimo-stop ()
  "Stop a running marimo server with SIGINT."
  (interactive)
  (let ((process (init-marimo--read-process)))
    (interrupt-process process)
    (message "Stopping marimo for %s..."
             (file-name-nondirectory (process-get process 'notebook)))))

(defun my-marimo-check (&optional fix)
  "Run `marimo check' on the current file.

With prefix argument FIX, apply marimo's safe automatic fixes in place."
  (interactive "P")
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file"))
  (when (buffer-modified-p)
    (save-buffer))
  (let* ((default-directory (file-name-directory buffer-file-name))
         (command (append (init-marimo--command default-directory)
                          (list "check")
                          (when fix (list "--fix"))
                          (list buffer-file-name))))
    (compilation-start
     (mapconcat #'shell-quote-argument command " ")
     'compilation-mode
     (lambda (_) "*marimo-check*"))))

(defun my-marimo-setup ()
  "Install or update marimo and watchdog as an isolated uv tool."
  (interactive)
  (unless (executable-find "uv")
    (user-error "uv not found; install it from https://docs.astral.sh/uv/"))
  (async-shell-command
   "uv tool install --upgrade --with watchdog 'marimo[recommended]'"
   "*marimo-setup*"))

(defvar init-marimo-prefix)
(define-prefix-command 'init-marimo-prefix)
(declare-function init-marimo-prefix nil)
(keymap-global-set "C-c j" #'init-marimo-prefix)
(keymap-set init-marimo-prefix "e" #'my-marimo-edit)
(keymap-set init-marimo-prefix "o" #'my-marimo-open)
(keymap-set init-marimo-prefix "c" #'my-marimo-check)
(keymap-set init-marimo-prefix "i" #'my-marimo-insert-cell)
(keymap-set init-marimo-prefix "l" #'my-marimo-log)
(keymap-set init-marimo-prefix "k" #'my-marimo-stop)
(keymap-set init-marimo-prefix "m" #'my-marimo-insert-markdown-cell)
(keymap-set init-marimo-prefix "s" #'my-marimo-setup)

(provide 'init-marimo)

;;; init-marimo.el ends here
