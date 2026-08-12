;;; init-browser.el --- In-Emacs web browsing -*- lexical-binding: t; -*-

;; embr drives a headless Chromium from a Python daemon and paints the frames
;; it streams back into an ordinary buffer, so browsing needs neither xwidgets
;; nor a window manager.  The package is cloned by `my-install-packages'; the
;; Python environment and the browser binary are installed separately by
;; `my-browser-setup', which uses uv.  Nothing here starts either one at
;; startup.

(declare-function embr-navigate "embr" (url))

(defconst init-browser-python-version "3.12"
  "Python version uv provisions for embr.  embr itself requires 3.10+.")

(defconst init-browser-venv
  (expand-file-name "embr/.venv"
                    (or (getenv "XDG_DATA_HOME")
                        (expand-file-name ".local/share" "~")))
  "Virtual environment embr runs its Python daemon from.

This is the path `embr-python' defaults to, computed the same way embr
computes it.  Keeping it means embr's own `embr-install-or-update-chromium'
still works as a fallback: its setup.sh reuses an existing venv and only
downloads the browser.")

(defun my-browser-setup ()
  "Create or refresh embr's Python environment with uv.

Replaces the `python3 -m venv' in embr's setup.sh, which builds the venv
from whichever python3 happens to be first on PATH -- Homebrew, pixi, or
a distro package on Linux, all with different lifetimes.  uv downloads a
standalone CPython instead, so macOS and Linux end up on the same
interpreter and the venv survives changes to the rest of the system.

Installs Playwright and its Chromium build, matching
`embr-browser-engine'.  Safe to re-run: this is also the update path,
and `--clear' rebuilds the venv from scratch rather than layering onto
whatever was there, which uv's cache makes cheap."
  (interactive)
  (unless (executable-find "uv")
    (user-error "embr: uv not found; install it from https://docs.astral.sh/uv/"))
  (let* ((venv (shell-quote-argument init-browser-venv))
         (python (shell-quote-argument
                  (expand-file-name "bin/python" init-browser-venv))))
    (async-shell-command
     (mapconcat
      #'identity
      (list (format "uv venv --clear --python %s %s"
                    init-browser-python-version venv)
            (format "uv pip install --python %s playwright" python)
            (format "%s -m playwright install chromium" python))
      " && ")
     "*embr-setup*")))

(defun my-browser-open (&optional here)
  "Open embr and prompt for a URL or search term.

Called interactively, `embr-browse' takes no argument and lands on
`embr-home-url', leaving `embr-navigate' (\\`C-c C-l' inside the browser)
as the way to reach a page.  This command chains the two so that one key
both starts the browser and asks where to go.

With prefix argument HERE, reuse the running browser without prompting,
which is the plain `embr-browse' behaviour."
  (interactive "P")
  (embr-browse)
  (unless here
    (call-interactively #'embr-navigate)))

(defun init-browser-screen-size ()
  "Return the screen size to report to websites, as (WIDTH . HEIGHT).

Measures the monitor showing the selected frame rather than
`display-pixel-width', which reports the union of all monitors: on a
multi-head X11 session that union is what a website would see as an
implausible 5120x1440 screen.

Falls back to the 1920x1080 embr assumes by default when there is no
graphical frame to measure, which is the case for a daemon started
before any frame exists."
  (let ((geometry (and (display-graphic-p)
                       (cdr (assq 'geometry (frame-monitor-attributes))))))
    (if geometry
        (cons (nth 2 geometry) (nth 3 geometry))
      (cons 1920 1080))))

(defun init-browser-unscale-frames ()
  "Draw browser frames at one image pixel per screen pixel.

embr locates a click by subtracting the window's text-area origin from
the mouse position, which only works if the frame is displayed at the
size it was captured.  It inserts the JPEG with `create-image' and no
`:scale', so Emacs falls back to `image-scaling-factor', whose default
`auto' enlarges every image by `frame-char-width' / 10 once the
character cell is at least ten pixels wide.  The same font that leaves
that ratio at 1.00 on this Mac reaches 1.3 or more under X11, and the
page is then drawn a third larger than the viewport the browser reports:
clicks land short of the pointer, by more the further they are from the
top-left corner.  `pdf-view-mode' pins this variable for the same
reason."
  (setq-local image-scaling-factor 1))

(defun init-browser-display-method ()
  "Return the embr display method this machine can actually run.

`headed' and `headed-offscreen' launch the browser under xvfb-run, so
they need Xvfb and are effectively Linux-only.  `headed-offscreen' is
worth preferring where it exists because headless Chromium draws no
scroll bars.  Everywhere else -- macOS, or a Linux box without Xvfb
installed -- headless is the only option.

embr makes the same xvfb-run check itself and falls back to headless
with a message; deciding here keeps that message out of normal startup
on machines that were never going to have Xvfb."
  (if (and (eq system-type 'gnu/linux)
           (executable-find "xvfb-run"))
      'headed-offscreen
    'headless))

(use-package embr
  :if (package-installed-p 'embr)
  :defer t

  :custom
  ;; Vanilla Playwright Chromium, installed by `my-browser-setup'.  The
  ;; default `cloakbrowser' engine hides the browser from bot detection
  ;; better, but does so with
  ;; closed-source patches.  Chromium is the open-source half of the choice;
  ;; the price is captchas on sites that fingerprint aggressively.
  (embr-browser-engine 'chromium)

  ;; Same path embr defaults to, but stated so that it and
  ;; `my-browser-setup' cannot drift apart.
  (embr-python (expand-file-name "bin/python" init-browser-venv))

  ;; Decided per machine: Xvfb where it exists, headless otherwise.
  (embr-display-method (init-browser-display-method))

  ;; Size the viewport from the Emacs window and follow it across resizes.
  (embr-viewport-sizing 'dynamic)
  (embr-screen-width (car (init-browser-screen-size)))
  (embr-screen-height (cdr (init-browser-screen-size)))

  (embr-color-scheme 'dark)
  (embr-search-engine 'duckduckgo)
  (embr-scroll-method 'instant)
  (embr-scroll-step 100)
  (embr-tab-bar t)
  (embr-session-restore t)
  (embr-home-url "about:blank")

  ;; The canvas backend needs an Emacs built with the canvas patch, which this
  ;; one is not, so frames arrive as JPEG images.  30Hz hover tracking is what
  ;; that backend is tuned for.
  (embr-render-backend 'default)
  (embr-frame-source 'screencast)
  (embr-hover-rate 30)

  ;; embr binds this key to its transient menu as a command, so it can only be
  ;; a prefix for `C-c C-l' below once the menu itself moves one key deeper.
  ;; `embr-mode-map' is built when the package loads, which is after `:custom'
  ;; applies, so the value is in place by then.
  (embr-dispatch-key "C-c C-c")

  :hook
  ;; The buffer holds one image, not lines, so the number column is both
  ;; meaningless and a few pixels stolen from the page.
  ((embr-mode . init-ui-disable-line-numbers)
   (embr-mode . init-browser-unscale-frames))

  :bind
  (("C-c b b" . my-browser-open)
   ("C-c b i" . embr-browse-incognito)
   ("C-c b ?" . embr-info))

  :config
  ;; embr puts `embr-navigate' on `C-l', which costs `recenter-top-bottom'.
  ;; Removing the entry rather than binding it to nil lets the global
  ;; definition through again.
  (keymap-unset embr-mode-map "C-l" t)
  (keymap-set embr-mode-map "C-c C-l" #'embr-navigate))

;; Inside an embr buffer nearly every key is forwarded to the page, so global
;; bindings are unavailable there.  `C-x' and `M-x' are kept, and `C-c' is the
;; prefix for embr's own commands.

(when (package-installed-p 'embr)
  ;; Send every `browse-url' target -- links in Org, Eww, help buffers,
  ;; compilation output -- to embr, and make plain URLs in any buffer
  ;; clickable so there is something to send.
  (setq browse-url-browser-function #'embr-browse)
  (global-goto-address-mode 1))

(provide 'init-browser)

;;; init-browser.el ends here
