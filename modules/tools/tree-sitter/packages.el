;; -*- no-byte-compile: t; -*-
;;; tools/tree-sitter/packages.el

(package! tree-sitter
  :pin "48b06796a3b2e76ce004972d929de38146eafaa0")

(package! tree-sitter-langs
  :pin "3c0c82f9fb0a796f5ebd7e1e4c89f13d5ab6ef58")

(when (featurep! :editor evil +everywhere)
  (package! evil-textobj-tree-sitter
    :pin "607b71f38a1b2d7fa464814d968427435d31dd7c"))
