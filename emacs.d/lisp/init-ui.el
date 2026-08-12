;;; init-ui.el --- User interface -*- lexical-binding: t; -*-

;; Do not enumerate system fonts during startup; Emacs falls back gracefully.
(set-face-attribute 'default nil :family "MesloLGS NF" :height 160)


;;; Tab bar.

(setq tab-bar-show t)

(defun init-ui-enable-tab-bar (&optional frame)
  "Enable and display the tab bar in FRAME."
  (with-selected-frame (or frame (selected-frame))
    (tab-bar-mode 1)
    (set-frame-parameter nil 'tab-bar-lines 1)))

(init-ui-enable-tab-bar)

(add-hook 'after-make-frame-functions
          #'init-ui-enable-tab-bar)

(add-to-list 'default-frame-alist '(tab-bar-lines . 1))

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

(defun init-ui-disable-line-numbers ()
  "Disable line numbers in the current buffer.

`global-display-line-numbers-mode' has no exempt-modes list to opt out
of, so buffers that render something other than text -- a PDF page, a
browser frame -- switch it off from their own mode hook.  Mode hooks run
before `after-change-major-mode-hook', but the globalized mode does not
turn it back on there, so the result sticks."
  (display-line-numbers-mode -1))

(column-number-mode 1)
(global-hl-line-mode 1)
(add-hook 'prog-mode-hook
          (lambda () (setq-local show-trailing-whitespace t)))

(setq scroll-conservatively 101
      scroll-margin 3
      mouse-wheel-scroll-amount '(3 ((shift) . 1))
      mouse-wheel-progressive-speed nil)

(use-package which-key
  :if (package-installed-p 'which-key)
  :demand t
  :config (which-key-mode 1)
  :custom (which-key-idle-delay 0.35)
  (which-key-idle-secondary-delay 0.05)
  (which-key-side-window-location 'bottom)
  (which-key-show-remaining-keys t))


;;; Two-window layout rotation.

(require 'cl-lib)

(defun init-ui--window-layout-top-bottom-p (window-1 window-2)
  "Return non-nil when WINDOW-1 and WINDOW-2 are arranged top/bottom."
  (= (car (window-edges window-1))
     (car (window-edges window-2))))

(defun init-ui--window-state (window)
  "Save the relevant display state of WINDOW."
  (list :buffer  (window-buffer window)
        :start   (window-start window)
        :point   (window-point window)
        :hscroll (window-hscroll window)
        :vscroll (window-vscroll window)))

(defun init-ui--restore-window-state (window state)
  "Restore STATE into WINDOW."
  (set-window-buffer window (plist-get state :buffer))
  (set-window-start window (plist-get state :start))
  (set-window-point window (plist-get state :point))
  (set-window-hscroll window (plist-get state :hscroll))
  (set-window-vscroll window (plist-get state :vscroll)))

(defun init-ui--rotate-two-windows (direction)
  "Rotate a two-window layout in DIRECTION.

DIRECTION must be either `clockwise' or `counterclockwise'."
  (unless (= (count-windows 'no-minibuffer) 2)
    (user-error "This command requires exactly two windows"))

  (let* ((windows (window-list nil 'no-minibuffer))
         (window-1 (nth 0 windows))
         (window-2 (nth 1 windows))
         (top-bottom-p
          (init-ui--window-layout-top-bottom-p window-1 window-2))

         ;; Sort windows into visual order:
         ;;
         ;;   top, bottom
         ;; or
         ;;   left, right
         (ordered-windows
          (sort windows
                (if top-bottom-p
                    (lambda (a b)
                      (< (nth 1 (window-edges a))
                         (nth 1 (window-edges b))))
                  (lambda (a b)
                    (< (car (window-edges a))
                       (car (window-edges b)))))))

         (first-window  (nth 0 ordered-windows))
         (second-window (nth 1 ordered-windows))

         (first-state  (init-ui--window-state first-window))
         (second-state (init-ui--window-state second-window))

         (selected-state
          (if (eq (selected-window) first-window)
              first-state
            second-state))

         ;; Determine which saved state goes into the first and second
         ;; positions of the new layout.
         ;;
         ;; For top/bottom -> left/right:
         ;;
         ;;   clockwise:        bottom -> left, top -> right
         ;;   counterclockwise: top -> left, bottom -> right
         ;;
         ;; For left/right -> top/bottom:
         ;;
         ;;   clockwise:        left -> top, right -> bottom
         ;;   counterclockwise: right -> top, left -> bottom
         (new-states
          (pcase (list direction top-bottom-p)
            (`(clockwise t)
             (list second-state first-state))
            (`(clockwise nil)
             (list first-state second-state))
            (`(counterclockwise t)
             (list first-state second-state))
            (`(counterclockwise nil)
             (list second-state first-state))
            (_
             (error "Invalid rotation direction: %S" direction))))

         ;; Use a harmless buffer while rebuilding the layout. This avoids
         ;; temporarily displaying the same PDF buffer in both windows.
         (temporary-buffer
          (get-buffer-create " *window-layout-rotation*")))

    ;; Remove the original buffers temporarily before changing the split.
    (set-window-buffer first-window temporary-buffer)
    (set-window-buffer second-window temporary-buffer)

    ;; Keep FIRST-WINDOW and delete the other one.
    (delete-other-windows first-window)

    ;; Change top/bottom into left/right, or vice versa.
    (let* ((new-window
            (if top-bottom-p
                (split-window-right)
              (split-window-below)))
           (new-windows
            (list first-window new-window)))

      ;; Restore buffers and their positions.
      (cl-mapc #'init-ui--restore-window-state
               new-windows
               new-states)

      ;; Keep focus on the same buffer as before rotation.
      (let ((selected-index
             (cl-position selected-state new-states :test #'eq)))
        (when selected-index
          (select-window (nth selected-index new-windows)))))))

(defun my-rotate-windows-clockwise ()
  "Rotate a two-window layout clockwise."
  (interactive)
  (init-ui--rotate-two-windows 'clockwise))

(defun my-rotate-windows-counterclockwise ()
  "Rotate a two-window layout counterclockwise."
  (interactive)
  (init-ui--rotate-two-windows 'counterclockwise))

;;; Active window indication.

(setq window-divider-default-right-width 2
      window-divider-default-bottom-width 2)

(window-divider-mode 1)

(set-face-attribute 'mode-line-active nil
                    :weight 'bold
                    :box '(:line-width 2 :color "#5e81ac"))

(set-face-attribute 'mode-line-inactive nil
                    :weight 'normal
                    :box '(:line-width 1 :color "gray40"))


(provide 'init-ui)

;;; init-ui.el ends here
