;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-

(setq package-enable-at-startup nil
      gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6
      frame-inhibit-implied-resize t)

;; Use English for Emacs packages and every subprocess it starts (including
;; Git), while leaving UTF-8 file handling configured in `init-base'.
(set-language-environment "English")
(setenv "LANGUAGE" "en")
(setenv "LC_ALL" "C")
(setenv "LC_MESSAGES" "C")

;; Route keyboard input through the GTK input-method context instead of Emacs's
;; own XIM client.  With fcitx5 the XIM path never engages: keystrokes land in
;; the buffer raw and Shift-based Chinese/ASCII switching does nothing.  The GTK
;; path goes through fcitx5's im module (im-fcitx5.so) over D-Bus and works.
;; Read when a frame is created, so it has to be set here rather than in `init'.
;;
;; `x-gtk-use-native-input' is a C-level DEFVAR compiled in only under USE_GTK,
;; so it is absent from the macOS (NS) build.  The `boundp' guard keeps this a
;; no-op there, and also keeps the byte-compiler from reporting an assignment to
;; a free variable when the file is compiled or linted on macOS.
(when (boundp 'x-gtk-use-native-input)
  (setq x-gtk-use-native-input t))

;; File-name handlers are mainly for remote files and slow down startup.
(defvar init-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist init-file-name-handler-alist)))

(dolist (mode '(menu-bar-mode tool-bar-mode scroll-bar-mode))
  (when (fboundp mode)
    (funcall mode -1)))

(setq initial-frame-alist '((fullscreen . maximized)))
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(provide 'early-init)

;;; early-init.el ends here
