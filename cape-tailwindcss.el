;;; cape-tailwindcss.el --- Capf for TailwindCSS class names  -*- lexical-binding:t -*-

;; Copyright (C) 2025-present CHEN Xian'an (a.k.a `realazy').

;; Maintainer: xianan.chen@gmail.com
;; Package-Requires: ((cape))
;; URL: https://github.com/cxa/cape-tailwindcss
;; Keywords: tailwind, css, completion

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; See <https://www.gnu.org/licenses/> for GNU General Public License.

;;; Commentary:

;; This package provides the `cape-tailwindcss' completion function.

;;; Code:

(require 'cape)

(defcustom cape-tailwindcss-class-attributes
  '("className" "class:list" "class" "ngClass")
  "The HTML attributes for which to provide class completions."
  :type '(repeat string))

(defcustom cape-tailwindcss-classes-fn #'cape-tailwindcss--classes
  "Function to get Tailwind CSS class list."
  :type 'function)

(defcustom cape-tailwindcss-company-kind-fn #'cape-tailwindcss--company-kind
  "Function to get company kind for class item."
  :type 'function)

(defcustom cape-tailwindcss-annotation-fn #'cape-tailwindcss--annotation
  "Function to get annotation for class item."
  :type 'function)

(defcustom cape-tailwindcss-triggerable-fn #'cape-tailwindcss--triggerable-p
  "Function to detect if `cape-tailwindcss' can complete at current point."
  :type 'function)


(defvar cape-tailwindcss--key 'cape-tailwind)
(defvar cape-tailwindcss--kind-key 'cape-tailwindcss--kind)

(defun cape-tailwindcss--string-node-p (node)
  (or (string-suffix-p "string" (treesit-node-type node))
      (string-suffix-p "string" (treesit-node-type (treesit-node-parent node)))))

(defun cape-tailwindcss--triggerable-p ()
  "Is current point can insert tailwind class names?"
  (when-let* ((pos (point))
              (node (treesit-node-at pos))
              ((cape-tailwindcss--string-node-p node))
              ((not (eq ?/ (char-before (car (cape--bounds 'symbol)))))))
    (while (and node (not (string-suffix-p "attribute" (treesit-node-type node))))
      (setq node (treesit-node-parent node)))

    (and-let* ((node node)
               (named-children (treesit-node-children node t))
               ((length= named-children 2))
               (attr-name (treesit-node-text (car named-children)))
               ((seq-contains-p cape-tailwindcss-class-attributes attr-name))))))

(defun cape-tailwindcss--classes ()
  (and-let* ((proj (project-current))
             (proj-root (project-root proj))
             ((get-text-property 0 cape-tailwindcss--key proj-root)))))

(defun cape-tailwindcss--company-kind (item)
  (when-let* ((kind (alist-get (get-text-property 0 cape-tailwindcss--kind-key item)
                               eglot--kind-names)))
    (pcase kind
      ("EnumMember" 'enum-member)
      ("TypeParameter" 'type-parameter)
      (_ (intern (downcase kind))))))

(defun cape-tailwindcss--annotation (_item)
  "Annotation for ITEM."
  " Tailwind")

(advice-add 'eglot--request :around
            (defun cape-tailwind--eglot--request/around (orig-fn &rest args)
              (let ((resp (apply orig-fn args)))
                (when-let* ((proj (project-current))
                            (proj-root (project-root proj))
                            ((not (get-text-property 0 cape-tailwindcss--key proj-root)))
                            (method (nth 1 args))
                            (params (nth 2 args))
                            ( (and (eq method :textDocument/completion)
                                   (eq 1 (plist-get (plist-get params :context)
                                                    :triggerKind))))
                            (items (append (if (vectorp resp) resp
                                             (plist-get resp :items)) nil))
                            ;; if we got an item like this, we are sure it's tailwindcss
                            ((seq-some (lambda (i) (string= "*:" (plist-get i :label))) items))
                            (capf-items
                             (mapcar (lambda (i)
                                       (let ((label (plist-get i :label)))
                                         (put-text-property 0 1 cape-tailwindcss--kind-key
                                                            (plist-get i :kind) label)
                                         label))
                                     items)))
                  (put-text-property 0 1 cape-tailwindcss--key capf-items proj-root))
                resp)))

(advice-add 'lsp--merge-results :before
            (defun cape-tailwindcss--lsp--merge-results/before (results method)
              (when-let* ((proj (project-current))
                          (proj-root (project-root proj))
                          ((not (get-text-property 0 cape-tailwindcss--key proj-root)))
                          ((string= method "textDocument/completion"))
                          (result (seq-find (lambda (r)
                                              (seq-some (lambda (i)
                                                          (string= "*:" (gethash "label" i)))
                                                        (and (lsp-completion-list? r)
                                                             (lsp:completion-list-items r))))
                                            results))
                          (items (lsp:completion-list-items result))
                          (capf-items
                           (mapcar (lambda (i)
                                     (let ((label (gethash "label" i)))
                                       (put-text-property 0 1 cape-tailwindcss--kind-key
                                                          (gethash "kind" i) label)
                                       label))
                                   items)))
                (message "items legth: %d"(length capf-items))
                (put-text-property 0 1 cape-tailwindcss--key capf-items proj-root))))

(defvar cape-tailwindcss--properties
  (list :annotation-function (lambda (i) (and cape-tailwindcss-annotation-fn
                                              (funcall cape-tailwindcss-annotation-fn i)))
        :company-kind (lambda (i) (and cape-tailwindcss-company-kind-fn
                                       (funcall cape-tailwindcss-company-kind-fn i)))
        :exclusive 'no
        :category 'cape-tailwindcss)
  "Completion extra properties for `cape-tailwindcss'.")

(defun cape-tailwindcss-reset ()
  (interactive)
  (when-let* ((proj (project-current))
              (proj-root (project-root proj)))
    (put-text-property 0 1 cape-tailwindcss--key nil proj-root)))

;;;###autoload
(defun cape-tailwindcss-capf (&optional skip-triggerable-check)
  "Tailwind CSS class capf.
By default, it checks whether the point can be completed with class names.
Set SKIP-TRIGGERABLE-CHECK to t to allow completion at any point."
  (when-let* ((classes (funcall cape-tailwindcss-classes-fn))
              ((or skip-triggerable-check (funcall cape-tailwindcss-triggerable-fn))))
    (pcase-let ((`(,beg . ,end) (cape--bounds 'symbol)))
      (when-let* ((pos (save-excursion
                         (goto-char beg)
                         (search-forward ":" (1+ end) t))))
        (setq beg pos))
      `(,beg ,end ,classes ,@cape-tailwindcss--properties))))

;;;###autoload
(defun cape-tailwindcss (&optional interactive)
  "Complete Tailwind CSS class names at any point."
  (interactive (list t))
  (if interactive
      (cape-interactive #'cape-tailwindcss)
    (cape-tailwindcss-capf t)))

(provide 'cape-tailwindcss)
;;; cape-tailwindcss.el ends here
