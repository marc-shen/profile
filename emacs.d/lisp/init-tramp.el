;;; init-tramp.el --- Fast remote file access -*- lexical-binding: t; -*-

(require 'tramp)

;; TRAMP-RPC keeps TRAMP's transparent file-name interface, but handles file
;; operations through a small MessagePack-RPC server over SSH.  Since this
;; configuration installs it from Git, use checksum-verified release artifacts
;; instead of requiring a local Rust toolchain to build a source-keyed server.
(use-package tramp-rpc
  :demand t
  :custom
  (tramp-default-method "rpc")
  (tramp-rpc-deploy-git-build-policy 'release))

(provide 'init-tramp)

;;; init-tramp.el ends here
