;;; init-helix.el --- Helix modal editing -*- lexical-binding: t; -*-

;; helix-mode (https://github.com/mgmarlow/helix-mode) is a small keybinding
;; layer, not a full emulation framework like Evil.  It adds two buffer-local
;; minor modes -- `helix-normal-mode' and `helix-insert-mode' -- whose keymaps
;; live in `minor-mode-map-alist', so they outrank the global map but leave
;; everything else in this configuration intact.  Anything the layer does not
;; bind still falls through to the ordinary Emacs binding, which is why `C-x',
;; `M-x' and the `C-c' prefix below keep working in normal state.
;;
;; The upstream package ships integrations for `project.el', `eglot', `xref',
;; tree-sitter, `multiple-cursors' and `avy'.  The last three are picked up with
;; `locate-library' at load time, so `multiple-cursors' (see init-development.el)
;; and `avy' only need to be installed, not loaded, for `helix-multiple-cursors-*'
;; and `gw' (goto word) to exist.

(require 'seq)

(declare-function helix-define-key "helix-core")
(declare-function helix-insert-mode "helix-core" (&optional arg))
(declare-function helix-insert-exit "helix-core")
(declare-function helix-normal-mode "helix-core" (&optional arg))

(defvar my-helix-exempt-modes
  '(special-mode                        ; magit, compilation, org-agenda, ...
    dired-mode
    magit-mode
    vterm-mode
    eshell-mode
    term-mode
    comint-mode
    treemacs-mode
    pdf-view-mode
    image-mode)
  "Major modes that keep their own single-key bindings instead of Helix.

`helix-mode' is all-or-nothing: it hooks `after-change-major-mode-hook'
and turns `helix-normal-mode' on in every non-minibuffer buffer.  In a
Magit status buffer that would shadow `s'/`u'/`c', in Dired `d'/`x', and
in vterm every key that should reach the shell -- so those modes are
switched back off.  Entries are matched with `derived-mode-p', hence the
`special-mode' catch-all.  WDired deliberately opts back into Helix for
the duration of filename editing; see `my-helix-wdired-enter'.")

;; `defvar' preserves an existing value when this file is evaluated again.
;; Remove the former exemption explicitly so the WDired policy also takes
;; effect without restarting Emacs.
(setq my-helix-exempt-modes (delq 'wdired-mode my-helix-exempt-modes))

(defun my-helix-exempt-p ()
  "Return non-nil if the current buffer should not use Helix keys."
  (seq-some #'derived-mode-p my-helix-exempt-modes))

(defun my-helix-disable-in-exempt-buffers ()
  "Turn `helix-normal-mode' back off in `my-helix-exempt-modes' buffers."
  (when (and (bound-and-true-p helix-normal-mode)
             (my-helix-exempt-p))
    (helix-normal-mode -1)))

;;; `j k' as an alternative ESC.

;; The upstream `helix-jj-setup' hard-codes the `j j' sequence (see the TODO in
;; helix-jj.el), so `j k' gets its own implementation along the same lines:
;; `j' does not insert itself immediately, it starts a timer instead; a `k'
;; typed before the timer fires cancels it and leaves insert state, anything
;; else flushes the withheld `j' and runs normally.  Unlike the upstream
;; version this is also installed in a graphical frame, where ESC does work but
;; is out of the way.

(defvar my-helix-jk-timeout 0.2
  "Seconds to wait for the `k' of a `j k' escape sequence.")

(defvar-local my-helix-jk--timer nil
  "Timer withholding the `j' of a possible `j k' sequence, or nil.")

(defun my-helix-jk--cancel ()
  "Cancel a pending `j k' sequence without inserting its withheld `j'."
  (when my-helix-jk--timer
    (cancel-timer my-helix-jk--timer)
    (setq my-helix-jk--timer nil)))

(defun my-helix-jk--flush ()
  "Insert the withheld `j' and cancel the pending sequence."
  (when my-helix-jk--timer
    (my-helix-jk--cancel)
    ;; Not `self-insert-command': this also runs from the timer, where
    ;; `last-command-event' is whatever the last real command left behind.
    (insert "j")))

(defun my-helix-jk--flush-from-timer (buffer)
  "Flush a pending `j k' sequence in BUFFER after the timeout expired."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (my-helix-jk--flush))))

(defun my-helix-jk-j ()
  "Withhold `j' for `my-helix-jk-timeout', waiting for a `k'.

In a minibuffer insert it immediately: file names and command arguments must
not acquire a delay or interpret a literal `j k' as a mode change."
  (interactive)
  (if (minibufferp)
      (self-insert-command 1)
    ;; A second `j' means the first one was not the start of an escape: emit it
    ;; and let this one open a fresh window.
    (my-helix-jk--flush)
    (setq my-helix-jk--timer
          (run-with-timer my-helix-jk-timeout nil
                          #'my-helix-jk--flush-from-timer (current-buffer)))))

(defun my-helix-jk-k ()
  "Leave insert state when `k' completes a `j k' sequence, else insert `k'.

In a minibuffer always insert `k' literally; use ESC to enter normal state."
  (interactive)
  (if (minibufferp)
      (self-insert-command 1)
    (if my-helix-jk--timer
        (progn
          (my-helix-jk--cancel)
          (helix-insert-exit))
      (self-insert-command 1))))

(defun my-helix-jk--maybe-flush ()
  "Flush a pending `j' before any command other than the sequence keys.

Runs from `pre-command-hook', so the withheld `j' lands before the next
command sees the buffer -- whether that command inserts a character, moves
point or saves the file."
  (when (and my-helix-jk--timer
             (not (memq this-command '(my-helix-jk-j my-helix-jk-k))))
    (my-helix-jk--flush)))

(defun my-helix-jk-setup ()
  "Bind `j k' as an alternative way to exit `helix-insert-mode'."
  (add-hook 'pre-command-hook #'my-helix-jk--maybe-flush)
  (helix-define-key 'insert "j" #'my-helix-jk-j)
  (helix-define-key 'insert "k" #'my-helix-jk-k))

;;; Helix in completion minibuffers.

(defvar-local my-helix-minibuffer--active nil
  "Non-nil when this minibuffer was put into Helix insert state.")

(defvar-local my-helix-minibuffer--saved-cursor-type nil
  "Value of `cursor-type' before Helix was enabled in this minibuffer.")

(defvar-local my-helix-minibuffer--cursor-was-local nil
  "Whether `cursor-type' was buffer-local before minibuffer Helix started.")

(defun my-helix-minibuffer-setup ()
  "Start a completion minibuffer in Helix insert state.

Plain `read-string' and confirmation prompts have no completion table and keep
their ordinary Emacs behavior.  Vertico's bindings fall through the sparse
Helix insert map, while ESC switches to the full Helix normal state."
  (when (and minibuffer-completion-table
             (not my-helix-minibuffer--active))
    (setq-local my-helix-minibuffer--active t
                my-helix-minibuffer--saved-cursor-type cursor-type
                my-helix-minibuffer--cursor-was-local
                (local-variable-p 'cursor-type))
    ;; Keep the cursor change local even if a future Emacs version stops making
    ;; `cursor-type' automatically buffer-local.
    (setq-local cursor-type cursor-type)
    (when (bound-and-true-p helix-normal-mode)
      (helix-normal-mode -1))
    (helix-insert-mode 1)))

(defun my-helix-minibuffer-cleanup ()
  "Remove every Helix state installed by `my-helix-minibuffer-setup'."
  (when my-helix-minibuffer--active
    ;; A minibuffer can also disappear through `C-g' or an error.  Do not leave
    ;; a timer able to insert into the hidden, reusable minibuffer afterward.
    (my-helix-jk--cancel)
    (when (bound-and-true-p helix-insert-mode)
      (helix-insert-mode -1))
    (when (bound-and-true-p helix-normal-mode)
      (helix-normal-mode -1))
    (if my-helix-minibuffer--cursor-was-local
        (setq cursor-type my-helix-minibuffer--saved-cursor-type)
      (kill-local-variable 'cursor-type))
    (setq my-helix-minibuffer--active nil)))

;;; Helix while editing filenames with WDired.

(defvar-local my-helix-wdired--active nil
  "Non-nil when WDired activated Helix in this buffer.")

(defvar-local my-helix-wdired--saved-cursor-type nil
  "Value of `cursor-type' before entering WDired.")

(defvar-local my-helix-wdired--cursor-was-local nil
  "Whether `cursor-type' was buffer-local before entering WDired.")

(defun my-helix-wdired-enter (function &rest arguments)
  "Run FUNCTION with ARGUMENTS, then start WDired in Helix normal state."
  (let ((saved-cursor-type cursor-type)
        (cursor-was-local (local-variable-p 'cursor-type)))
    (prog1 (apply function arguments)
      (when (and (eq major-mode 'wdired-mode)
                 (bound-and-true-p helix-global-mode))
        (setq-local my-helix-wdired--active t
                    my-helix-wdired--saved-cursor-type saved-cursor-type
                    my-helix-wdired--cursor-was-local cursor-was-local)
        (when (bound-and-true-p helix-insert-mode)
          (helix-insert-mode -1))
        (helix-normal-mode 1)))))

(defun my-helix-wdired-exit (&rest _)
  "Remove the Helix state owned by WDired after returning to Dired."
  ;; WDired changes `major-mode' back by hand, so the ordinary
  ;; `after-change-major-mode-hook' is not sufficient for this transition.
  (when (and my-helix-wdired--active (eq major-mode 'dired-mode))
    (my-helix-jk--cancel)
    (when (bound-and-true-p helix-insert-mode)
      (helix-insert-mode -1))
    (when (bound-and-true-p helix-normal-mode)
      (helix-normal-mode -1))
    (if my-helix-wdired--cursor-was-local
        (setq cursor-type my-helix-wdired--saved-cursor-type)
      (kill-local-variable 'cursor-type))
    (setq my-helix-wdired--active nil)))

(use-package helix
  :if (package-installed-p 'helix)
  :config
  ;; Helix binds `C-c' to `comment-line', which would swallow the whole `C-c'
  ;; prefix in normal state -- `C-c r', `C-c c', the `C-c g' Git prefix and the
  ;; `C-c e' multiple-cursors set all live there.  Emacs keeps the prefix;
  ;; commenting stays on the native `M-;', which works in both states.
  (keymap-unset helix-normal-state-keymap "C-c" t)

  ;; Runs after `helix-mode-maybe-activate', which upstream adds at the default
  ;; depth, so the mode is switched off again in the same command.
  (add-hook 'after-change-major-mode-hook
            #'my-helix-disable-in-exempt-buffers 90)

  ;; A terminal cannot distinguish ESC from the meta prefix (helix-mode issue
  ;; #24), and even in a graphical frame ESC is a reach, so `j k' stands in for
  ;; it everywhere except minibuffers, where both letters must remain literal.
  (my-helix-jk-setup)

  ;; Match Dired's `q' binding: enter WDired from Dired and leave it again from
  ;; WDired normal state.  Helix's mode-specific map outranks its global normal
  ;; map, whose remapped self-insertion would otherwise make `q' undefined.
  (helix-define-key 'normal "q" #'wdired-exit 'wdired-mode)

  ;; Upstream deliberately excludes minibuffers from `helix-mode'.  Completion
  ;; minibuffers opt in separately and start in insert state, so file names and
  ;; commands can be typed immediately; ESC exposes normal-state navigation.
  (add-hook 'minibuffer-setup-hook #'my-helix-minibuffer-setup 90)
  (add-hook 'minibuffer-exit-hook #'my-helix-minibuffer-cleanup -90)

  ;; WDired changes major modes without a symmetric major-mode hook on exit.
  ;; Advise its public exit commands rather than the internal mode-transition
  ;; helper, which can be unavailable as a Lisp function in dumped Emacs builds.
  (with-eval-after-load 'wdired
    (unless (advice-member-p #'my-helix-wdired-enter
                             'wdired-change-to-wdired-mode)
      (advice-add 'wdired-change-to-wdired-mode
                  :around #'my-helix-wdired-enter))
    (dolist (command '(wdired-finish-edit wdired-abort-changes wdired-exit))
      (unless (advice-member-p #'my-helix-wdired-exit command)
        (advice-add command :after #'my-helix-wdired-exit))))

  ;; `helix-mode' is a toggle, not a minor mode: calling it twice would turn
  ;; Helix back off if this file were ever reloaded.  It installs the
  ;; `after-change-major-mode-hook' entry and the `keyboard-quit' advice, but
  ;; only activates the current buffer, so `helix-mode-all' covers the buffers
  ;; that already exist -- *scratch* at startup, everything else on a reload.
  (unless (bound-and-true-p helix-global-mode)
    (helix-mode)
    (helix-mode-all))

  ;; `helix-mode-all' does not consult the exemption hook.
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (my-helix-disable-in-exempt-buffers))))

(provide 'init-helix)

;;; init-helix.el ends here
