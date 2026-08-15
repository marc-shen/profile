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
`special-mode' catch-all.")

(defun my-helix-exempt-p ()
  "Return non-nil if the current buffer should not use Helix keys."
  (seq-some #'derived-mode-p my-helix-exempt-modes))

(defun my-helix-disable-in-exempt-buffers ()
  "Turn `helix-normal-mode' back off in `my-helix-exempt-modes' buffers."
  (when (and (bound-and-true-p helix-normal-mode)
             (my-helix-exempt-p))
    (helix-normal-mode -1)))

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

  ;; A terminal cannot distinguish ESC from the meta prefix, so `jj' is the way
  ;; out of insert state there.  See helix-mode issue #24.
  (unless (display-graphic-p)
    (helix-jj-setup 0.2))

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
