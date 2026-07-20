# cape-tailwindcss

> [!IMPORTANT]
> This repository is archived and no longer maintained. For the Eglot and
> Tailwind multi-server setup previously documented here,
> [Eglotx](https://github.com/cxa/eglotx) is the maintained path: enable its
> preset catalog and keep Eglot's ordinary completion-at-point integration.
> Eglotx incorporates the performance lessons from this experiment, but it is
> not a drop-in replacement for `cape-tailwindcss-capf` and does not replace
> this package's lsp-mode integration. Users who need the standalone CAPF can
> continue using the final archived revision.

Capfs for Tailwind CSS

## Motivation

The Tailwind CSS language server typically returns around 20,000 completion items. Emacs handles parsing and converting large JSON into Elisp objects poorly, which causes about a 2-second lag on my MacBook Pro M1. Because these class items are (almost) the same across most projects, we can cache them and provide a capf (completion-at-point function) to complete blazingly fast!

## Install & Configuration Example

``` emacs-lisp
(use-package cape-tailwindcss
  :vc (:url "https://github.com/cxa/cape-tailwindcss")
  :commands (cape-tailwindcss-capf)
  :preface
  (defun my/eglot-capf-hook ()
    (let ((capf (cape-capf-super #'eglot-completion-at-point
                                 #'cape-tailwindcss-capf)))
      (if (not eglot--managed-mode)
          (remove-hook 'completion-at-point-functions capf 'local)
        (remove-hook 'completion-at-point-functions #'eglot-completion-at-point 'local)
        (add-hook 'completion-at-point-functions capf nil 'local))))

  (defun my/lsp-capf-hook ()
    (let ((capf (cape-capf-super #'lsp-completion-at-point
                                 #'cape-tailwindcss-capf)))
      (if (not lsp-completion-mode)
          (remove-hook 'completion-at-point-functions capf 'local)
        (remove-hook 'completion-at-point-functions #'lsp-completion-at-point 'local)
        (add-hook 'completion-at-point-functions capf nil 'local))))
  
  :bind (:map cape-prefix-map
              ("i" . cape-tailwindcss))

  :hook
  (eglot-managed-mode  . my/eglot-capf-hook)
  (lsp-completion-mode . my/lsp-capf-hook))
```

## Note

See <https://github.com/cxa/eglot-lspx> for instructions on using the Tailwind CSS language server alongside other LSP servers with Eglot.
