;;; init-tramp.el --- Fast remote file access -*- lexical-binding: t; -*-

(require 'tramp)

;; TRAMP-RPC keeps TRAMP's transparent file-name interface, but handles file
;; operations through a small MessagePack-RPC server over SSH.  It is installed
;; by `my-install-packages', so a fresh machine must be able to start without
;; it first.  Until then standard TRAMP remains available as the fallback.
(if (require 'tramp-rpc nil t)
    (setq tramp-default-method "rpc"
          ;; This configuration installs TRAMP-RPC from Git.  Prefer
          ;; checksum-verified release artifacts to requiring a Rust toolchain
          ;; for building a source-keyed server binary.
          tramp-rpc-deploy-git-build-policy 'release)
  (message "TRAMP-RPC is not installed; run M-x my-install-packages"))

(provide 'init-tramp)

;;; init-tramp.el ends here
