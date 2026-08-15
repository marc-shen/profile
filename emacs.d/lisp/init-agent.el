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
;; The agent itself is not an Emacs package.  Claude's adapter is installed
;; separately, and reaching it is what `init-agent-ensure-executable-path'
;; below is for:
;;
;;   npm install -g @agentclientprotocol/claude-agent-acp

(defconst init-agent-acp-executable "claude-agent-acp"
  "The Claude ACP adapter, as named on PATH.

This is the default first element of `agent-shell-anthropic-claude-acp-command';
it is repeated here because the path fix below has to look for it before
agent-shell is loaded.")

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

(defun init-agent-ensure-executable-path ()
  "Make `init-agent-acp-executable' reachable when npm's bin directory is not.

The same gap `init-base.el' patches for `~/.local/bin': a GUI Emacs started
from the Finder inherits launchd's environment, never runs a shell, and so
never sees the directory nvm's shell function puts on PATH.

Both `exec-path' and PATH are extended, not just `exec-path'.  The adapter is
a Node script beginning with `#!/usr/bin/env node': `exec-path' is what lets
Emacs find the script, but PATH is what lets `env' inside it find Node.

Does nothing when the adapter is already reachable, so an Emacs started from
a shell keeps whichever Node version that shell had selected."
  (unless (executable-find init-agent-acp-executable)
    (when-let* ((directory (init-agent-nvm-bin-directory init-agent-acp-executable)))
      (add-to-list 'exec-path directory)
      (setenv "PATH" (concat directory path-separator (getenv "PATH"))))))

(use-package agent-shell
  :if (package-installed-p 'agent-shell)
  ;; `C-c a' is `org-agenda' and `C-c A' is free, so the agent takes the
  ;; shifted key.  `agent-shell' reuses this project's running shell when
  ;; there is one and starts a new shell otherwise, which is the entry point
  ;; worth a binding; `agent-shell-new-shell', `agent-shell-resume-session'
  ;; and the rest stay on `M-x'.
  :bind ("C-c A" . agent-shell)
  :custom
  ;; Only Claude's adapter is installed, but the picker is kept rather than
  ;; bypassed with a bare `claude-code': it is the one place that lists the
  ;; other agents, so trying Gemini or Codex later needs no change here.
  (agent-shell-preferred-agent-config '(preselect . claude-code))
  :config
  ;; Deliberately not set: `agent-shell-anthropic-authentication' already
  ;; defaults to `:login t', which reuses the Claude subscription that the
  ;; `claude' CLI logged in with.  Setting an API key instead would bill the
  ;; same requests a second time.  To use one anyway:
  ;;
  ;;   (setq agent-shell-anthropic-authentication
  ;;         (agent-shell-anthropic-make-authentication
  ;;          :api-key (lambda ()
  ;;                     (auth-source-pick-first-password
  ;;                      :host "api.anthropic.com"))))
  (init-agent-ensure-executable-path))

(provide 'init-agent)

;;; init-agent.el ends here
