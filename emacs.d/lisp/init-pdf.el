;;; init-pdf.el --- PDF viewing environment -*- lexical-binding: t; -*-

;; The commands bound in `:config' and the AUCTeX variables set at the end of
;; this file only come into existence once their packages load, which `:defer'
;; postpones to the first PDF.  Loading them at compile time is enough for the
;; byte-compiler to see them and costs nothing at startup; `noerror' keeps the
;; file compilable on a machine where the packages are not installed yet.
(eval-when-compile
  (require 'pdf-view nil t)
  (require 'pdf-annot nil t)
  (require 'image-mode nil t)
  (require 'tex nil t))

(use-package pdf-tools
  :if (package-installed-p 'pdf-tools)
  :defer t

  :init
  ;; Register PDF Tools without rebuilding epdfinfo on every startup.
  (pdf-loader-install)

  :mode
  ("\\.pdf\\'" . pdf-view-mode)

  :hook
  ((pdf-view-mode . init-ui-disable-line-numbers))

  :custom
  (pdf-annot-activate-created-annotations t)
  (pdf-view-continuous t)
  (pdf-view-midnight-colors '("#d8dee9" . "#2e3440"))

  :config
  ;; Scrolling.
  (keymap-set pdf-view-mode-map
              "j" #'pdf-view-next-line-or-next-page)
  (keymap-set pdf-view-mode-map
              "k" #'pdf-view-previous-line-or-previous-page)
  (keymap-set pdf-view-mode-map
              "h" #'image-backward-hscroll)
  (keymap-set pdf-view-mode-map
              "l" #'image-forward-hscroll)

  ;; Page navigation.
  (keymap-set pdf-view-mode-map
              "n" #'pdf-view-next-page-command)
  (keymap-set pdf-view-mode-map
              "p" #'pdf-view-previous-page-command)
  (keymap-set pdf-view-mode-map
              "g" #'pdf-view-goto-page)

  ;; Zoom and fitting.
  (keymap-set pdf-view-mode-map
              "=" #'pdf-view-enlarge)
  (keymap-set pdf-view-mode-map
              "+" #'pdf-view-enlarge)
  (keymap-set pdf-view-mode-map
              "-" #'pdf-view-shrink)
  (keymap-set pdf-view-mode-map
              "0" #'pdf-view-scale-reset)
  (keymap-set pdf-view-mode-map
              "W" #'pdf-view-fit-width-to-window)
  (keymap-set pdf-view-mode-map
              "P" #'pdf-view-fit-page-to-window)

  ;; Search and outline.
  (keymap-set pdf-view-mode-map
              "/" #'isearch-forward)
  (keymap-set pdf-view-mode-map
              "o" #'pdf-outline)

  ;; Reading mode.
  (keymap-set pdf-view-mode-map
              "C-c C-n" #'pdf-view-midnight-minor-mode)

  ;; Annotations.
  (keymap-set pdf-view-mode-map
              "C-c C-a h"
              #'pdf-annot-add-highlight-markup-annotation)
  (keymap-set pdf-view-mode-map
              "C-c C-a u"
              #'pdf-annot-add-underline-markup-annotation)
  (keymap-set pdf-view-mode-map
              "C-c C-a t"
              #'pdf-annot-add-text-annotation))

;; AUCTeX and SyncTeX integration.
(with-eval-after-load 'tex
  (setq TeX-view-program-selection
        '((output-pdf "PDF Tools"))
        TeX-view-program-list
        '(("PDF Tools" TeX-pdf-tools-sync-view)))

  (add-hook 'TeX-after-compilation-finished-functions
            #'TeX-revert-document-buffer))

(provide 'init-pdf)

;;; init-pdf.el ends here
