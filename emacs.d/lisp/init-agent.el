;;; init-agent.el --- Coding agents -*- lexical-binding: t; -*-

;; agent-shell talks to a coding agent over ACP (the Agent Client Protocol) and
;; renders the conversation into an ordinary Emacs buffer: the agent's output is
;; text that `isearch', the kill ring and every other Emacs command can reach.
;; The alternative packages wrap the vendor's terminal UI in a vterm or eat
;; buffer instead, which tracks the vendor's own releases more closely at the
;; cost of leaving the transcript inside a terminal emulator.
;;
;; ACP is also why only this one package is needed.  Claude, Gemini, Codex and
;; the rest each ship their own ACP adapter, and agent-shell drives all of them
;; through the same shell, so adding a second agent later is a line of
;; configuration rather than a second package with a second set of keys.
;;
;; The agents themselves are not Emacs packages.  Their ACP adapters are
;; installed separately, and reaching them is what
;; `init-agent-ensure-executable-path' below is for:
;;
;;   npm install -g @agentclientprotocol/codex-acp
;;   npm install -g @agentclientprotocol/claude-agent-acp

(defconst init-agent-acp-executables '("codex-acp" "claude-agent-acp")
  "ACP adapters to look for in nvm's bin directory when missing from PATH.")

(defun init-agent-nvm-bin-directory (executable)
  "Return the newest nvm-installed directory holding EXECUTABLE, or nil.

nvm keeps every Node version under its own directory and leaves no stable
symlink to the active one, so the directory cannot simply be written down.

Sorting with `version<' rather than `string<' matters as soon as two
installed versions differ in digit count: v9 sorts above v10 alphabetically."
  (when-let* ((matches (file-expand-wildcards
                        (expand-file-name
                         (format "~/.nvm/versions/node/*/bin/%s" executable))))
              (newest (car (sort matches
                                 :key (lambda (file)
                                        (if (string-match "/node/v?\\([0-9.]+\\)/"
                                                          file)
                                            (match-string 1 file)
                                          "0"))
                                 :lessp #'version<
                                 :reverse t))))
    (file-name-directory newest)))

(defun init-agent-ensure-executable-path (executable)
  "Make EXECUTABLE reachable when npm's bin directory is not.

The same gap `init-base.el' patches for `~/.local/bin': a GUI Emacs started
from the Finder inherits launchd's environment, never runs a shell, and so
never sees the directory nvm's shell function puts on PATH.

Both `exec-path' and PATH are extended, not just `exec-path'.  The adapter is
a Node script beginning with `#!/usr/bin/env node': `exec-path' is what lets
Emacs find the script, but PATH is what lets `env' inside it find Node.

Does nothing when the adapter is already reachable, so an Emacs started from
a shell keeps whichever Node version that shell had selected."
  (unless (executable-find executable)
    (when-let* ((directory (init-agent-nvm-bin-directory executable)))
      (add-to-list 'exec-path directory)
      (setenv "PATH" (concat directory path-separator (getenv "PATH"))))))

(use-package agent-shell
  :if (package-installed-p 'agent-shell)
  ;; `agent-shell' reuses this project's running shell when
  ;; there is one and starts a new shell otherwise, which is the entry point
  ;; worth a binding; `agent-shell-new-shell', `agent-shell-resume-session'
  ;; and the rest stay on `M-x'.
  :bind ("C-c a" . agent-shell)
  :custom
  ;; Keep the picker, with Codex selected by default, so other agents remain
  ;; available without changing the configuration.
  (agent-shell-preferred-agent-config '(preselect . codex))
  ;; New conversations start with an empty prompt.  Add context explicitly
  ;; with copy/paste instead of importing the current buffer or line.
  (agent-shell-context-sources nil)
  :config
  ;; The global ESC runs `keyboard-escape-quit', which also closes other
  ;; windows.  Helix's insert ESC changes state; in normal state cancel only
  ;; the current operation.
  (keymap-set agent-shell-mode-map "<escape>" #'keyboard-quit)
  ;; Both adapters default to CLI login; no API key is configured here.
  (dolist (executable init-agent-acp-executables)
    (init-agent-ensure-executable-path executable)))

(provide 'init-agent)

;;; init-agent.el ends here
