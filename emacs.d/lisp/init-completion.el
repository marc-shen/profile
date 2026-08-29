;;; init-completion.el --- Completion frameworks -*- lexical-binding: t; -*-

;; Three stacks: Vertico and friends complete in the minibuffer, Corfu and Cape
;; complete in the buffer, and Minuet asks a language model to continue the code
;; at point.  The first two share `completion-styles', so they are configured
;; together even though neither depends on the other; the third is here because
;; what makes it work is the way it stays out of the other two's way.


;;; Minibuffer completion.

(use-package vertico
  :demand t
  :init (vertico-mode 1)
  ;; Keys stay at their Vertico defaults here: TAB accepts the selection
  ;; (`vertico-insert'), C-n/C-p move through candidates.  Only the Corfu popup
  ;; cycles with TAB / S-TAB.
  :custom (vertico-cycle t) (vertico-count 12))

(use-package orderless
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  ;; Eglot narrows candidates server-side; without an explicit entry the
  ;; `eglot-capf' category falls back to plain prefix matching in the popup.
  (completion-category-overrides
   '((file (styles partial-completion basic))
     (eglot (styles orderless basic))
     (eglot-capf (styles orderless basic)))))

(use-package marginalia
  :demand t
  :init (marginalia-mode 1))

(use-package consult
  :bind (("C-s" . consult-line) ("C-x b" . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window) ("C-x C-r" . consult-recent-file)
         ("M-y" . consult-yank-pop) ("M-g g" . consult-goto-line)
         ("M-g i" . consult-imenu) ("M-s r" . consult-ripgrep)
         ;; fd replaces find: it walks the tree in parallel, skips whatever
         ;; .gitignore lists, and matches case-insensitively unless the pattern
         ;; itself is capitalized.  Together with the `~' flex dispatcher this
         ;; covers what fzf is normally reached for.
         ;;
         ;; Bound to `M-s d', not the more obvious `M-s f': Dired makes the
         ;; latter a prefix of its own (`M-s f C-s' searches file names only),
         ;; and a local map wins, so the binding would silently die in exactly
         ;; the buffers where searching a directory tree is most useful.
         ("M-s d" . consult-fd) ("C-c m" . consult-mode-command))
  ;; Dotfiles are the point of this repository, so do not let fd hide them; .git
  ;; itself only adds thousands of uninteresting object paths.
  :custom (consult-fd-args
           '((if (executable-find "fdfind" 'remote) "fdfind" "fd")
             "--full-path --hidden --exclude .git --color=never")))

(use-package embark
  :if (package-installed-p 'embark)
  :bind (("C-." . embark-act) ("C-;" . embark-dwim) ("C-h B" . embark-bindings))
  :init (setq prefix-help-command #'embark-prefix-help-command))
(use-package embark-consult
  :if (and (package-installed-p 'embark)
           (package-installed-p 'embark-consult))
  :after (embark consult))


;;; In-buffer completion.

(use-package corfu
  :demand t
  :init (global-corfu-mode 1)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  (corfu-quit-no-match 'separator)
  (corfu-popupinfo-delay '(0.5 . 0.2))
  :bind (:map corfu-map
              ;; TAB / S-TAB cycle the candidates, RET inserts the selection.
              ("TAB" . corfu-next) ([tab] . corfu-next)
              ("S-TAB" . corfu-previous) ([backtab] . corfu-previous)
              ("RET" . corfu-insert) ([return] . corfu-insert)
              ("M-TAB" . corfu-expand)
              ("C-g" . corfu-quit) ("M-d" . corfu-info-documentation))
  :config
  (corfu-popupinfo-mode 1)
  ;; Corfu grabs C-n/C-p through `next-line'/`previous-line' remappings.  Undo
  ;; them so those keys always move point; the popup then closes on its own,
  ;; since neither command matches `corfu-continue-commands'.
  (define-key corfu-map [remap next-line] nil)
  (define-key corfu-map [remap previous-line] nil))

;; Dabbrev is loaded here, eagerly, rather than left to the `require' inside
;; `cape--dabbrev-bounds'.  That `require' runs from `cape-dabbrev', which
;; Corfu calls from the `corfu-auto-delay' timer inside `while-no-input': a
;; keystroke arriving while dabbrev.el is being loaded aborts the load
;; part-way.  When the load is a native-compiled unit, the aborted unit stays
;; registered in the process with its relocations half-filled, and every later
;; attempt to load it fails -- in this session with `(setting-constant nil)',
;; reported by Corfu as "Corfu detected an error" on every keypress, since the
;; feature never got provided and each `cape-dabbrev' call retries the require.
;; Loading it at startup, outside any timer, is the whole fix; nothing below
;; changes what Cape does once dabbrev is in.
(require 'dabbrev)

(use-package cape
  :init
  ;; Use `add-hook' rather than `add-to-list': init.el is loaded inside
  ;; *scratch*, where `completion-at-point-functions' is buffer-local, so
  ;; `add-to-list' would register these backends in that buffer alone.
  (add-hook 'completion-at-point-functions #'cape-file 10)
  (add-hook 'completion-at-point-functions #'cape-keyword 20)
  (add-hook 'completion-at-point-functions #'cape-dabbrev 30)
  :custom
  ;; Scan buffers sharing the current major mode: broad enough to be useful in
  ;; a multi-file project, narrow enough to keep the candidate list relevant.
  ;; (The old `cape-dabbrev-check-other-buffers' no longer exists in Cape.)
  (cape-dabbrev-buffer-function #'cape-same-mode-buffers))

;; Emacs Lisp buffers set `completion-at-point-functions' locally without the
;; `t' marker, so the global Cape backends never run there.  Rebuild the list.
(add-hook 'emacs-lisp-mode-hook
          (lambda ()
            (setq-local completion-at-point-functions
                        (list #'elisp-completion-at-point #'cape-file
                              #'cape-dabbrev))))


;;; Completion from a language model.

;; Minuet sends the text around point to a model and offers what it would write
;; next.  Two decisions keep it from colliding with the stacks above.
;;
;; It is invoked by hand rather than on a timer.  `minuet-auto-suggestion-mode'
;; would draw its answer as an overlay at point, which is where Corfu already
;; puts its popup -- Corfu opens after `corfu-auto-delay', so in practice both
;; would be on screen at once -- and every keystroke would cost a request to a
;; metered API.  `minuet-complete-with-minibuffer' asks only when asked.
;;
;; It reads the answer in the minibuffer, not the popup.  A model returns whole
;; lines or whole functions, and the Corfu popup shows one line per candidate,
;; so a multi-line suggestion there is unreadable.  Vertico lists them, and
;; because `consult' is installed Minuet reaches for `consult--read', whose
;; `consult--insertion-preview' state shows each candidate inserted at point
;; while it is highlighted.  `minuet-add-single-line-entry' is left on, so a
;; multi-line suggestion also appears cut down to its first line.
;;
;; Nothing here touches `completion-at-point-functions', so the Cape backends
;; and the popup keymap are untouched: `M-i' cannot open a Corfu popup, and the
;; keys above cannot reach a model.

(defconst init-completion-minuet-services
  '((openai-fim-compatible "DEEPSEEK_API_KEY" "api.deepseek.com")
    (openai-compatible "OPENROUTER_API_KEY" "openrouter.ai"))
  "The Minuet providers this configuration knows how to reach.

Each entry is a provider, the environment variable its key is conventionally
kept in, and the auth-source host to look under otherwise.  Minuet's own
defaults already point `openai-fim-compatible' at DeepSeek and
`openai-compatible' at OpenRouter, so naming the provider is all either one
needs.

The first is preferred because it is fill-in-the-middle: the model is given
the text on both sides of point and asked only for the part between, rather
than a chat model being talked into answering with code and nothing else.")

(defun init-completion-minuet-api-key (variable host)
  "Return the API key in environment VARIABLE, or auth-source HOST.

Reading the environment alone is not enough.  A key exported from
`~/.zshrc' reaches an Emacs started from a shell, but zsh reads that file
only for interactive shells, and a macOS Emacs opened from the Finder
inherits launchd's environment without running a shell at all -- so the
same configuration has a key in one Emacs and not in the other.
Auth-source has no such gap: `~/.authinfo.gpg' is read by Emacs itself.

  machine api.deepseek.com login minuet password sk-...

Called for each request rather than once at startup, so that adding the key
takes effect without restarting Emacs."
  (or (getenv variable)
      (auth-source-pick-first-password :host host)))

(defun init-completion-minuet-provider ()
  "Return the first service in `init-completion-minuet-services' with a key.

Falls back to the first service listed, so that a missing key is reported
against a named provider instead of leaving `minuet-provider' meaningless."
  (or (car (seq-find (pcase-lambda (`(,_provider ,variable ,host))
                       (init-completion-minuet-api-key variable host))
                     init-completion-minuet-services))
      (caar init-completion-minuet-services)))

(use-package minuet
  ;; Guarded on the package alone, deliberately.  Testing for a key here would
  ;; leave `M-i' bound to its default `tab-to-tab-stop' whenever the key was
  ;; missing -- a command that silently inserts whitespace, which is worse than
  ;; no binding and looks nothing like a failed completion.  With the binding
  ;; unconditional, a missing key surfaces as Minuet's own "provider is not
  ;; available" error.
  :if (package-installed-p 'minuet)
  ;; `M-i' is `tab-to-tab-stop', which the indentation commands of every mode
  ;; here have made vestigial.  The README suggests `M-y', but that is
  ;; `consult-yank-pop' above.
  :bind ("M-i" . minuet-complete-with-minibuffer)
  :custom
  (minuet-provider (init-completion-minuet-provider))
  ;; A request that produced nothing otherwise fails silently, leaving `M-i'
  ;; looking like it did nothing at all.  This reports the cause; the full log
  ;; is in `minuet-buffer-name' either way.
  (minuet-show-error-message-on-minibuffer t)
  :config
  ;; Minuet accepts a function for `:api-key' and calls it per request, which
  ;; is what makes `init-completion-minuet-api-key' reach auth-source at all --
  ;; the default is the name of an environment variable and nothing else.
  (pcase-dolist (`(,provider ,variable ,host) init-completion-minuet-services)
    (let ((options (intern (format "minuet-%s-options" provider))))
      (set options
           (plist-put (symbol-value options) :api-key
                      (lambda ()
                        (init-completion-minuet-api-key variable host)))))))

(provide 'init-completion)

;;; init-completion.el ends here
