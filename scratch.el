;;; scratch.el --- Avoid data loss for scratch buffers

;; Package-Requires: ((emacs "24") (s "1.9.0"))
;; Version: 0.2

;;; Commentary:
;;

;;; Code:

(eval-when-compile
  (require 's))


;; * Custom variables

;;;###autoload
(defgroup scratch nil
  "Manage scratch buffers"
  :group 'editing)

;;;###autoload
(defcustom scratch-default-name "*scratch*"
  "Default name for scratch buffers."
  :type  'string
  :group 'scratch)

;;;###autoload
(defcustom scratch-create-when-blank-name t
  "If non-nil, leaving the buffer name blank in
`scratch-switch-to-buffer' creates a new scratch buffer.
Otherwise, switch to the default scratch buffer."
  :type  'boolean
  :group 'scratch)


;; * Entry points

;;;###autoload
(defun scratch-create (buffer-name)
  "Create a new scratch buffer with name BUFFER-NAME.

If another buffer already exists with that name, a new buffer
will still be created by uniquifying BUFFER-NAME.

New buffers created this way is considedered a scratch buffer: it
is put in `scratch-mode' to avoid data loss."
  (interactive (list (if current-prefix-arg
                         (read-from-minibuffer "Create scratch buffer: ")
                       scratch-default-name)))
  (switch-to-buffer
   (scratch--get-buffer-create (generate-new-buffer-name buffer-name))))

(defmacro scratch--define-wrapper (doc prompt form)
  (declare (debug (stringp stringp &rest form)))
  (let ((fun (car form)))
    `(progn
       ;;;###autoload
       (defun ,(intern (format "scratch-%s" fun)) (&optional buffer-or-name)
         ,(concat
           doc "\n"
           (format "See `%s' for details." fun) "\n\n"
           (s-word-wrap
            emacs-lisp-docstring-fill-column
            (s-collapse-whitespace
             "If BUFFER-OR-NAME does not identify an existing
              buffer, create a new buffer with that name. Any
              buffer created this way is considered a scratch
              buffer: it is put in `scratch-mode' to avoid data
              loss."))
           "\n\n"
           (s-word-wrap
            emacs-lisp-docstring-fill-column
            (s-collapse-whitespace
             "As a special case, if BUFFER-OR-NAME is left blank
              and `scratch-scratch-create-when-blank-name' is non-nil,
              always create a new scratch buffer with name
              `scratch-scratch-default-name'.")))
         (interactive ,(concat "B" prompt))
         (let ((buffer (scratch--get-buffer-create buffer-or-name)))
           ,form)))))

;;;###autoload (autoload 'scratch-switch-to-buffer "scratch")
(scratch--define-wrapper
 "Display buffer BUFFER-OR-NAME in the selected window."
 "Switch to buffer: "
 (switch-to-buffer buffer nil t))

;;;###autoload (autoload 'scratch-pop-to-buffer "scratch")
(scratch--define-wrapper
 "Select buffer BUFFER-OR-NAME in some window, preferably a different one."
 "Pop to buffer: "
 (pop-to-buffer buffer (if current-prefix-arg t)))

;;;###autoload
(define-minor-mode scratch-mode
  "Minor mode for temporary buffers.

Emacs prompts to save modified buffers in this mode before
killing them."
  :lighter " scratch"
  ;; Offer saving scratch buffers when exiting emacs
  (setq buffer-offer-save scratch-mode))


;; * Internal machinery

;; ** Activation of the minor mode

;; Changing major mode doesn't kill `scratch-mode'
(put 'scratch-mode 'permanent-local t)

;; Saving a scratch buffer should deactivate `scratch-mode'
(defun scratch--deactivate-after-save ()
  "Deactivate `scratch-mode' after a buffer has been saved."
  (when (and scratch-mode
             (buffer-file-name))
    (scratch-mode -1)))

(add-hook 'after-save-hook 'scratch--deactivate-after-save)

;; ** Save scratch buffers before killing them

(defun scratch--save-before-kill ()
  "Offer to save modified `scratch-mode' buffers before killing them."
  (when (and scratch-mode
             (not (buffer-file-name))
             (buffer-modified-p)
             (yes-or-no-p
              (format
               "Buffer `%s' has not been saved. Save it now? "
               (buffer-name))))
    (call-interactively #'save-buffer)))

(add-hook 'kill-buffer-hook 'scratch--save-before-kill)

;; ** Create scratch buffers

(defun scratch--get-buffer-create (&optional buffer-or-name)
  "Return the buffer specified by BUFFER-OR-NAME, creating a new one if needed.

If BUFFER-OR-NAME is nil or blank and
`scratch-scratch-create-when-blank-name' is non-nil, it defaults to
`scratch-scratch-default-name'.

If BUFFER-OR-NAME doesn't specify an existing buffer, create a
new buffer with that name. Any buffer created this way is
considered a scratch buffer: it is put in `scratch-mode' to avoid
data loss."
  (setq buffer-or-name (or buffer-or-name ""))
  (let ((buffer (get-buffer buffer-or-name)))
    (unless buffer
      ;; Create a new scratch buffer
      (when (and scratch-create-when-blank-name
                 (string= buffer-or-name ""))
        (setq buffer-or-name scratch-default-name))
      (setq buffer (generate-new-buffer buffer-or-name))
      (with-current-buffer buffer
        (scratch-mode 1)
        (let ((buffer-file-name (concat default-directory buffer-or-name)))
          (set-auto-mode))))
    buffer))

;; * Footer

(provide 'scratch)

;;; scratch.el ends here
