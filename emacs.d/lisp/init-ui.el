;;; init-ui.el --- User interface -*- lexical-binding: t; -*-

(defvar display-line-numbers-type)

;; `Emacs Client.app' is the Dock-facing launcher.  A macOS daemon is a
;; separate AppKit application, so without this it also gets its own Dock tile.
;; Emacs promotes itself back to a regular application when it creates a GUI
;; frame, hence this must run after every new frame rather than only at startup.
;; Standalone Emacs is unchanged: it has no client launcher to represent it.
(defun init-ui-hide-macos-daemon-dock-icon (&optional _frame)
  "Keep the macOS Emacs daemon from adding a second Dock icon."
  (when (and (eq system-type 'darwin)
             (daemonp)
             (featurep 'ns)
             (fboundp 'ns-do-applescript))
    (condition-case nil
        (ns-do-applescript
         (concat "use framework \"AppKit\"\n"
                 "current application's NSApplication's sharedApplication()'s "
                 "setActivationPolicy:1"))
      (error nil))))

(init-ui-hide-macos-daemon-dock-icon)
(add-hook 'after-make-frame-functions
          #'init-ui-hide-macos-daemon-dock-icon)

;; Keep Latin/code glyphs monospaced and choose one deterministic Chinese font
;; instead of letting the platform select a different fallback for each glyph
;; or weight.  Mapping only CJK scripts preserves Meslo for ASCII, Nerd Font
;; icons, and source code.
(defconst init-ui-default-font-family "MesloLGS NF")
(defconst init-ui-default-font-height 160)
(defconst init-ui-cjk-font-families
  '("Sarasa Mono SC"
    "Noto Sans Mono CJK SC"
    "PingFang SC"
    "Noto Sans CJK SC")
  "Preferred CJK font families, in cross-platform fallback order.")

(defvar init-ui-cjk-font-family nil
  "CJK font family selected for the current graphical environment.")

(defun init-ui-select-cjk-font (&optional frame)
  "Return the first installed preferred CJK font for FRAME."
  (catch 'family
    (dolist (family init-ui-cjk-font-families)
      (when (find-font (font-spec :family family) frame)
        (throw 'family family)))
    nil))

(defun init-ui-configure-fonts (&optional frame)
  "Apply the Latin and unified CJK fonts to FRAME."
  (let ((frame (or frame (selected-frame))))
    (when (frame-live-p frame)
      (set-face-attribute 'default frame
                          :family init-ui-default-font-family
                          :height init-ui-default-font-height)
      (when (display-graphic-p frame)
        (when-let* ((family (init-ui-select-cjk-font frame))
                    (cjk-font (font-spec :family family)))
          (setq init-ui-cjk-font-family family)
          (dolist (target '(han cjk-misc
                            (#x2014 . #x2014) ; em dash
                            (#x2018 . #x201f) ; curly quotation marks
                            (#x2026 . #x2026))) ; ellipsis
            (set-fontset-font nil target cjk-font frame)))))))

;; Set the default face for this and future frames, then install the CJK
;; mappings in every graphical frame created by the daemon or emacsclient.
(set-face-attribute 'default nil
                    :family init-ui-default-font-family
                    :height init-ui-default-font-height)
(init-ui-configure-fonts)
(add-hook 'after-make-frame-functions #'init-ui-configure-fonts)


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

;; A steady cursor everywhere: `blink-cursor-mode' is a global minor mode, so
;; this covers frames created later by `emacsclient' too.
(blink-cursor-mode -1)

(column-number-mode 1)
(setq mode-line-compact 'long
      ;; Keep the modal state visible; collapse secondary mode lighters such as
      ;; Flyspell, Yasnippet, Which-Key, Outline, and Visual Line into `…'.
      mode-line-collapse-minor-modes
      '(not helix-normal-mode helix-insert-mode))
(global-hl-line-mode 1)
(add-hook 'prog-mode-hook
          (lambda () (setq-local show-trailing-whitespace t)))

;;; File character count in the mode line.

(defvar-local init-ui--file-character-count nil
  "Cached number of non-whitespace characters in the visited file.")

(defvar-local init-ui--file-word-count nil
  "Cached mixed Chinese and English word count in the visited file.")

(defvar-local init-ui--file-character-count-removed 0
  "Non-whitespace characters about to be removed by the current edit.")

(defvar-local init-ui--file-word-count-timer nil
  "Idle timer waiting to refresh the current file's word count.")

(defvar-local init-ui--region-count-cache nil
  "Cached (BEG END TICK WORDS CHARACTERS) for the active selection.")

(defun init-ui--count-non-whitespace (beg end)
  "Count non-whitespace characters between BEG and END."
  (save-excursion
    (save-match-data
      (goto-char beg)
      (let ((count 0))
        (while (re-search-forward "\\S-" end t)
          (setq count (1+ count)))
        count))))

(defun init-ui--han-character-p (character)
  "Return non-nil when CHARACTER is a Han ideograph."
  (or (= character #x3007)
      (<= #x3400 character #x4dbf)
      (<= #x4e00 character #x9fff)
      (<= #xf900 character #xfaff)
      (<= #x20000 character #x2fa1f)
      (<= #x30000 character #x323af)))

(defun init-ui--latin-word-character-p (character)
  "Return non-nil when CHARACTER can form an English/Latin word."
  (or (and (<= ?A character) (<= character ?Z))
      (and (<= ?a character) (<= character ?z))
      (and (<= ?0 character) (<= character ?9))
      (and (> character 127)
           (when-let* ((name (get-char-code-property character 'name)))
             (string-prefix-p "LATIN " name)))))

(defun init-ui--count-mixed-words (beg end)
  "Count English words and individual Han characters from BEG through END."
  (save-excursion
    (goto-char beg)
    (let ((count 0)
          in-latin-word)
      (while (< (point) end)
        (let ((character (char-after)))
          (cond
           ((init-ui--han-character-p character)
            (setq count (1+ count)
                  in-latin-word nil))
           ((init-ui--latin-word-character-p character)
            (unless in-latin-word
              (setq count (1+ count)))
            (setq in-latin-word t))
           ;; Keep decomposed accents and internal apostrophes/hyphens inside
           ;; the surrounding Latin word without counting them as characters
           ;; that can start a word on their own.
           ((and in-latin-word
                 (or (eq (get-char-code-property character 'general-category)
                         'Mn)
                     (and (memq character '(?' ?’ ?-))
                          (< (1+ (point)) end)
                          (init-ui--latin-word-character-p
                           (char-after (1+ (point))))))))
           (t
            (setq in-latin-word nil))))
        (forward-char 1))
      count)))

(defun init-ui--file-character-count-eligible-p ()
  "Return non-nil when the current buffer should show a file character count."
  (and buffer-file-name
       (not (derived-mode-p 'special-mode))
       (not (bound-and-true-p so-long-mode))))

(defun init-ui--refresh-file-character-count ()
  "Recompute the current file's cached word and character counts."
  (when (init-ui--file-character-count-eligible-p)
    (save-restriction
      (widen)
      (setq init-ui--file-word-count
            (init-ui--count-mixed-words (point-min) (point-max))
            init-ui--file-character-count
            (init-ui--count-non-whitespace (point-min) (point-max))))
    (force-mode-line-update)))

(defun init-ui--refresh-file-word-count (buffer)
  "Refresh the cached word count for BUFFER after an idle delay."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq init-ui--file-word-count-timer nil)
      (when (init-ui--file-character-count-eligible-p)
        (save-restriction
          (widen)
          (setq init-ui--file-word-count
                (init-ui--count-mixed-words (point-min) (point-max))))
        (force-mode-line-update)))))

(defun init-ui--schedule-file-word-count ()
  "Schedule one coalesced word-count refresh for the current file."
  (when (timerp init-ui--file-word-count-timer)
    (cancel-timer init-ui--file-word-count-timer))
  (setq init-ui--file-word-count-timer
        (run-with-idle-timer 0.3 nil #'init-ui--refresh-file-word-count
                             (current-buffer))))

(defun init-ui--cancel-file-word-count ()
  "Cancel the current buffer's pending word-count refresh."
  (when (timerp init-ui--file-word-count-timer)
    (cancel-timer init-ui--file-word-count-timer))
  (setq init-ui--file-word-count-timer nil))

(defun init-ui--file-character-count-before-change (beg end)
  "Remember the character count removed between BEG and END."
  (setq init-ui--file-character-count-removed
        (if (numberp init-ui--file-character-count)
            (init-ui--count-non-whitespace beg end)
          0)))

(defun init-ui--file-character-count-after-change (beg end _old-length)
  "Update the cached count after text changed between BEG and END."
  (if (numberp init-ui--file-character-count)
      (setq init-ui--file-character-count
            (+ init-ui--file-character-count
               (- (init-ui--count-non-whitespace beg end)
                  init-ui--file-character-count-removed)))
    (init-ui--refresh-file-character-count))
  (setq init-ui--file-character-count-removed 0)
  (init-ui--schedule-file-word-count)
  (force-mode-line-update))

(defun init-ui-setup-file-character-count ()
  "Enable efficient mode-line character counting for the current file."
  (when (init-ui--file-character-count-eligible-p)
    (unless (and (numberp init-ui--file-word-count)
                 (numberp init-ui--file-character-count))
      (init-ui--refresh-file-character-count))
    (add-hook 'before-change-functions
              #'init-ui--file-character-count-before-change nil t)
    (add-hook 'after-change-functions
              #'init-ui--file-character-count-after-change nil t)
    (add-hook 'after-revert-hook
              #'init-ui--refresh-file-character-count nil t)
    (add-hook 'kill-buffer-hook
              #'init-ui--cancel-file-word-count nil t)))

(defun init-ui--compact-count (count)
  "Return COUNT compactly, retaining exact values below ten thousand."
  (let ((text
         (cond
          ((< count 10000) (number-to-string count))
          ((< count 1000000) (format "%.1fk" (/ count 1000.0)))
          (t (format "%.1fM" (/ count 1000000.0))))))
    (replace-regexp-in-string "\\.0\\([kM]\\)\\'" "\\1" text)))

(defun init-ui--selected-region-counts ()
  "Return (WORDS CHARACTERS) for the active region, with a small cache."
  (when (use-region-p)
    (let* ((beg (region-beginning))
           (end (region-end))
           (tick (buffer-chars-modified-tick))
           (cached init-ui--region-count-cache))
      (unless (and cached
                   (= beg (nth 0 cached))
                   (= end (nth 1 cached))
                   (= tick (nth 2 cached)))
        (setq cached
              (list beg end tick
                    (init-ui--count-mixed-words beg end)
                    (init-ui--count-non-whitespace beg end))
              init-ui--region-count-cache cached))
      (list (nth 3 cached) (nth 4 cached)))))

(defun init-ui-file-character-count-mode-line ()
  "Show selected-region counts, or the whole file when nothing is selected."
  (when (and (init-ui--file-character-count-eligible-p)
             (numberp init-ui--file-word-count)
             (numberp init-ui--file-character-count))
    (let* ((region-counts (init-ui--selected-region-counts))
           (words (if region-counts (car region-counts)
                    init-ui--file-word-count))
           (characters (if region-counts (cadr region-counts)
                         init-ui--file-character-count)))
      (propertize
       (format "  %s%s词·%s字符"
               (if region-counts "选区 " "")
               (init-ui--compact-count words)
               (init-ui--compact-count characters))
       'help-echo
       (format (concat "%s：%d 词，%d 个非空白字符\n"
                       "词数：英文按词、汉字按字")
               (if region-counts "选区精确统计" "全文精确统计")
               words characters)))))

(defvar init-ui-file-character-count-mode-line
  '(:eval (init-ui-file-character-count-mode-line))
  "Mode-line construct displaying the current file's character count.")
(put 'init-ui-file-character-count-mode-line 'risky-local-variable t)

(unless (memq 'init-ui-file-character-count-mode-line
              (default-value 'mode-line-position))
  (setq-default mode-line-position
                (append (default-value 'mode-line-position)
                        '(init-ui-file-character-count-mode-line))))

(add-hook 'find-file-hook #'init-ui-setup-file-character-count)
(add-hook 'after-change-major-mode-hook #'init-ui-setup-file-character-count)

(setq scroll-conservatively 101
      scroll-margin 3
      mouse-wheel-scroll-amount '(3 ((shift) . 1))
      mouse-wheel-progressive-speed nil)

(use-package which-key
  :ensure nil
  :demand t
  :config
  (which-key-mode 1)
  ;; Paging through a long popup.  which-key normally puts this on the help
  ;; key after a prefix -- `C-c C-h' -- but `init-completion.el' points
  ;; `prefix-help-command' at `embark-prefix-help-command', which answers
  ;; `C-c C-h' with a searchable list instead.  That is the better tool when
  ;; the command's name is known and the key is not, so it keeps the help key;
  ;; paging gets its own.
  ;;
  ;; `which-key-paging-prefixes' is the documented way to do this and does not
  ;; work from here: `define-minor-mode' builds `which-key-mode-map' out of
  ;; that variable while which-key.el loads, so a value set afterwards is
  ;; never read.  Binding the key directly has the same effect.
  ;;
  ;; After `C-c <f5>' the popup stays up under a transient map, so paging
  ;; continues on bare `n' and `p'; `u' undoes the last key of the prefix and
  ;; `a' aborts.  Raise `which-key-side-window-max-height' (0.25 by default)
  ;; if a taller popup would suit better than paging.
  (dolist (prefix '("C-c" "C-x" "M-g" "M-s"))
    (keymap-set which-key-mode-map (concat prefix " <f5>")
                #'which-key-C-h-dispatch))
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
