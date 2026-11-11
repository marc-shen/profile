;;; init-proxy.el --- On-demand network proxy -*- lexical-binding: t; -*-

(require 'url-vars)

(defgroup init-proxy nil
  "On-demand proxy settings for Emacs and its subprocesses."
  :group 'environment)

(defcustom init-proxy-default-host "127.0.0.1"
  "Default proxy host offered by `set-proxy'."
  :type 'string
  :group 'init-proxy)

(defcustom init-proxy-default-port 7897
  "Default proxy port offered by `set-proxy'."
  :type 'integer
  :group 'init-proxy)

(defun set-proxy (host port)
  "Use the HTTP proxy at HOST and PORT for Emacs and subprocesses.

Interactively, offer `init-proxy-default-host' and
`init-proxy-default-port' as defaults.  The settings last for the current
Emacs process; run `unset-proxy' to restore direct access."
  (interactive
   (list (read-string "Proxy host: " init-proxy-default-host)
         (read-number "Proxy port: " init-proxy-default-port)))
  (when (string-empty-p host)
    (user-error "Proxy host cannot be empty"))
  (unless (and (integerp port) (<= 1 port 65535))
    (user-error "Proxy port must be between 1 and 65535"))
  (let* ((endpoint (format "%s:%d" host port))
         (url (concat "http://" endpoint)))
    ;; `url-proxy-services' is used by package.el and other url.el clients.
    (setq url-proxy-services
          `(("http" . ,endpoint)
            ("https" . ,endpoint)))
    ;; Child processes such as Git and curl conventionally read these.
    (dolist (name '("http_proxy" "https_proxy" "HTTP_PROXY" "HTTPS_PROXY"))
      (setenv name url))
    (message "Proxy enabled: %s" url)))

(defun unset-proxy ()
  "Disable the proxy configured by `set-proxy'."
  (interactive)
  (setq url-proxy-services nil)
  (dolist (name '("http_proxy" "https_proxy" "HTTP_PROXY" "HTTPS_PROXY"))
    (setenv name nil))
  (message "Proxy disabled; using direct connections"))

(provide 'init-proxy)

;;; init-proxy.el ends here
