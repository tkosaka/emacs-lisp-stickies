;;; stickies.el --- stickies

;; Copyright (C) 2009  KOSAKA Tomohiko

;; Author: KOSAKA Tomohiko <tomohiko.kosaka@gmail.com>
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

 ;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This program provides post-it notes in Emacs.
;; I've been using Stickies.app in Mac OSX for post-it notes, 
;; but recent days, I'm becoming emacs-addicted more and more,
;; so I created this elisp.
;;
;; When you execute the `stickies-open-sticky' function, 
;; it creates a new sticky buffer and a frame, 
;; and you can write down anything you want to remember.
;; Multiple stickies are available, and each sticky has own
;; buffer and a a frame.
;;
;; Note: Even when the sticky buffer is killed by stickies' killing functions, 
;; the sticky is not saved to a file, 
;; If you want to save the sticky, call `stickies-save-sticky' 
;; or set `stickies-save-stickies-before-kill' to t.
;;
;; stickies.el judges that the buffer and frame is of sticky
;; by its buffer name matches to `stickies-buffer-name-regexp',
;; so do not rename, kill, and etc. a sticky buffer.
;; Whenever you want to kill a sticky, use `stickies-kill-sticky', 
;; or `stickies-kill-all-stickies'.
;; When a sticky buffer disappears, stickies.el cannot manipulate 
;; the frame of the sticky.
;; 
;; If you want to open all the saved stickies, 
;; call `stickies-open-all-saved-stickies'.
;;
;; You can alter the frame setting for stickies
;; by changing `stickies-frame-alist'.
;; Consider to change `stickies-deviation-frame-geometries', 
;; `stickies-diff-x-offset', and `stickies-diff-y-offset'
;; if necessary.
;;
;; * For anything users:
;; There is anything-stickies.el for anything interface to stickies.
;; Try it if you wish.

;;; Installation:
;;
;; 1. Put sitckies.el (and anything-stickies.el if you use) into a directory that 
;; Emacs recognizes as a part of `load-path'.
;; You can also byte-compile these files.
;;
;; 2. Put the following into your init file (.emacs.el):
;;
;; (require 'stickies)
;;
;; Further example setting is described in the "Setting" section of this file, 
;; please read it if necessary.

;;; Setting: 
;; (require 'stickies)
;; ;(require 'anything-stickies) ;;; use anything interface
;; 
;; ;;; keybind
;; 
;; ;;; delete the current sticky file.
;; (global-set-key "\C-csd" '(lambda ()
;;                             (interactive)
;;                             (if (and (stickies-is-sticky-buffer (current-buffer))
;;                                      (y-or-n-p "Delete the sticky file?"))
;;                                 (stickies-delete-sticky-file))))
;; (global-set-key "\C-csk" 'stickies-kill-sticky) ;;; kill the current sticky.
;; (global-set-key "\C-csK" '(lambda ()
;;                             (interactive)
;;                             (if (y-or-n-p "Kill all stickies?")
;;                                 (stickies-kill-all-stickies))))
;; (global-set-key "\C-csn" 'stickies-open-sticky)
;; (global-set-key "\C-cso" 'stickies-open-all-saved-stickies)
;; 
;; (setq stickies-frame-alist
;;       '((mouse-color . "salmon") (cursor-color . "salmon") (background-color . "bisque") (foreground-color . "gray10") 
;;         (top . 80) (left . 70) (width . 60) (height . 20) (alpha . 80)
;;         ))
;; 
;; ;;; Save stickies when emacs is terminated.
;; (add-hook 'kill-emacs-hook 'stickies-save-all-stickies)
;; 
;; ;;; Automatically save stickies by 10 minutes.
;; (setq auto-save-stickies-timer
;;       (run-at-time t 600 'stickies-save-all-stickies))
;; 
;; ;;; Open all stickies when emacs starts.
;; ;(stickies-open-all-saved-stickies)

;;; Code:

(defgroup stickies nil
  "Stickies group"
  :group 'convenience
  :prefix "stickies-")

(defcustom stickies-directory (expand-file-name "stickies" user-emacs-directory)
  "Directory to save stickies."
  :group 'stickies
  :type 'directory)

(defcustom stickies-save-stickies-before-kill nil
  "When t, save the current sticky before it is killed."
  :group 'stickies
  :type 'boolean)

(defcustom stickies-deviation-frame-geometries t
  "When t, each sticky frame has a little bit different geometry.
   The differnce is given as the two variables:
   `stickies-diff-x-offset' and `stickies-diff-y-offset'."
  :group 'stickies
  :type 'boolean)

(defcustom stickies-diff-x-offset 40
  "The difference of the x-offset to the previous sticky frame."
  :group 'stickies
  :type 'integer)

(defcustom stickies-diff-y-offset 40
  "The difference of the y-offset to the previous sticky frame."
  :group 'stickies
  :type 'integer)

(defvar stickies-frame-alist default-frame-alist
  "Frame parameters for sticky buffers")

(defvar stickies-buffer-name-prefix "*sticky*"
  "Prefix of buffer names for sticky")

(defvar stickies-file-name-prefix "sticky"
  "Prefix of file names for sticky")

(defvar stickies-buffer-name-regexp
  (format "%s\\(\\|<[0-9]+>\\)" (replace-regexp-in-string "\*" "\\\\\*" stickies-buffer-name-prefix))
  "Regular expression that matches to buffer names of sticky.")

(defvar stickies-file-name-regexp
  (format "%s\\(\\|<[0-9]+>\\)" stickies-file-name-prefix)
  "Regular expression that matches to file names fo sticky.")

(defvar stickies-open-stickies-hook nil
  "Hook executed just after opening a sticky.")

(defvar stickies-kill-stickies-hook nil
  "Hook executed just before killing a sticky.")

(defun stickies-is-sticky-buffer (&optional buffer-or-name)
  "Return t if `buffer-or-name' is a sticky buffer."
  (if (not buffer-or-name)
      (setq buffer-or-name (buffer-name (current-buffer))))
  (let ((buffer-name
         (if (equal (type-of buffer-or-name) 'buffer)
             (buffer-name buffer-or-name)
           buffer-or-name)))
    (string-match stickies-buffer-name-regexp buffer-name)))

(defun stickies-get-buffer-number (&optional buffer)
  "Return the number of the sticky buffer named `buffer'.
   Note: the name of the number 1 buffer does not end with <1>."
  (if (not buffer)
      (setq buffer (current-buffer)))
  (let* ((buffer-name (buffer-name buffer))
         (num
          (when (stickies-is-sticky-buffer buffer)
            (replace-match "\\1" nil nil buffer-name))))
    (when num
      (if (string-match "<\\([0-9]+\\)>" num)
          (setq num (string-to-int (match-string 1 num)))
        (setq num 1)))
    num))

(defun stickies-convert-buffer-name-to-file-name (&optional buffer)
  "Convert a buffer name of the `buffer' to the corresponding file name."
  (if (not buffer)
      (setq buffer (current-buffer)))
  (when (stickies-is-sticky-buffer buffer)
    (let* ((buffer-name (buffer-name buffer))
           (num
            (stickies-get-buffer-number buffer)))
      (if num
          (progn
            (if (= 1 num)
                (setq num "")
              (setq num (int-to-string num)))
            (format "%s%s" stickies-file-name-prefix num))
        ;;; num must exist.
        ;;; If the buffer is not a sticky buffer, 
        ;;; it needs to specify the file name.
        ;(read-file-name (format "Input the file name for %s" buffer-name))
        (error "Buffer is not a sticky buffer.")
        ))))

(defun stickies-convert-file-name-to-buffer-name (file-name)
  "Convert a `file-name' to the corresponding buffer name.
   If file-name does not match to `stickies-file-name-regexp', it returns nil"
  (let ((buffer-name
         (replace-regexp-in-string
          "[0-9]+"
          "<\\&>"
          (replace-regexp-in-string stickies-file-name-prefix stickies-buffer-name-prefix file-name))))
    (if (stickies-is-sticky-buffer buffer-name)
        buffer-name)))

(defun stickies-set-frame-position (&optional buffer frame)
  "Set neat position for sticky frame."
  (when stickies-deviation-frame-geometries
    (if (not buffer)
        (setq buffer (current-buffer)))
    (if (not buffer)
        (setq frame (selected-frame)))
    (let ((top-orig (cdr (assoc 'top stickies-frame-alist)))
          (left-orig (cdr (assoc 'left stickies-frame-alist)))
          (buffer-number (stickies-get-buffer-number buffer)))
      (if (and top-orig left-orig buffer-number)
          (set-frame-position frame (+ left-orig (* (1- buffer-number) stickies-diff-x-offset))
                              (+ top-orig (* (1- buffer-number) stickies-diff-y-offset)))))))

(defun stickies-get-all-stickies-buffers ()
  "Retrieve the list of all stickies buffers."
  (remove-if
   '(lambda (item) (not item))
   (mapcar
    '(lambda (buffer)
       (if (stickies-is-sticky-buffer buffer)
           buffer))
    (buffer-list))))

(defun stickies-open-sticky (&optional file-path content)
  "Create a new sticky buffer and a frame.
   If you specify `file-path', the content of the file will be shown in the new sticky.
   If you specify `content', the new sticky will set it's buffer content to `content'."
  (interactive)
  (let* ((buffer-name (if file-path
                          (or (stickies-convert-file-name-to-buffer-name (file-name-nondirectory file-path))
                              (generate-new-buffer-name stickies-buffer-name-prefix))
                        (generate-new-buffer-name stickies-buffer-name-prefix))))
    
    (switch-to-buffer-other-frame buffer-name)

    (if file-path
        (insert-file-contents file-path nil nil nil t)
      (when content
        (erase-buffer)
        (insert buffer-content)))

    (run-hooks 'stickies-open-stickies-hook)
    (modify-frame-parameters (selected-frame) stickies-frame-alist)
    (stickies-set-frame-position (current-buffer) (selected-frame))))

(defun stickies-open-all-saved-stickies ()
  "Open all save stickies files."
  (interactive)
  (dolist (saved-file (directory-files stickies-directory nil stickies-file-name-regexp))
    (stickies-open-sticky (expand-file-name saved-file stickies-directory))))

(defun stickies-save-sticky (&optional buffer)
  "Save a sticky of the `buffer' to a file."
  (if (not (file-exists-p stickies-directory))
      (make-directory stickies-directory))

  (if (not buffer)
      (setq buffer (current-buffer)))

  (set-buffer buffer)
  (let ((buffer-content (buffer-substring (point-min) (point-max)))
        (buffer-to-save (get-buffer-create (format "%s.tmp" (buffer-name buffer))))
        (filename-to-save
         (expand-file-name
          (format "%s" (stickies-convert-buffer-name-to-file-name buffer))
          stickies-directory)))
    (with-current-buffer buffer-to-save
      (erase-buffer)
      (insert buffer-content)
      (write-file filename-to-save nil)
      (kill-buffer buffer-to-save))))

(defun stickies-save-all-stickies ()
  "Save all stickies to files."
  (interactive)
  (dolist (buffer (stickies-get-all-stickies-buffers))
    (stickies-save-sticky buffer)))

(defun stickies-kill-sticky (&optional buffer not-switch-frame)
  "Kill a sticky buffer and a frame related to `buffer'."
  (interactive)
  (unless buffer
    (setq buffer (current-buffer))
    (setq not-switch-frame t))

  (when (stickies-is-sticky-buffer buffer)
    (if not-switch-frame
        (set-buffer buffer)
      (switch-to-buffer-other-frame buffer))

    (run-hooks 'stickies-kill-stickies-hook)
    (if stickies-save-stickies-before-kill
        (stickies-save-sticky buffer))
    (kill-buffer buffer)
    (delete-frame (selected-frame))))

(defun stickies-kill-all-stickies ()
  "Kill all buffers and frames for stickies."
  (interactive)
  (let ((current-non-sticky-frame
         (if (not (stickies-is-sticky-buffer (current-buffer)))
             (selected-frame))))
    (dolist (frame (frame-list))
      (select-frame-set-input-focus frame)
      (when (stickies-is-sticky-buffer (current-buffer))
        (stickies-kill-sticky (current-buffer) t)))
    (if current-non-sticky-frame
        (select-frame-set-input-focus current-non-sticky-frame))))

(defun stickies-delete-sticky-file (&optional buffer)
  "Delete a sticky file of the `buffer'.
   Note: This function does not kill displayed sticky buffer."
  (interactive)
  (if (not buffer)
      (setq buffer (current-buffer)))
  (when (stickies-is-sticky-buffer buffer)
    (let ((file-path (expand-file-name
                      (stickies-convert-buffer-name-to-file-name buffer)
                      stickies-directory)))
      (if (file-exists-p file-path)
          (delete-file file-path)))))

(defun stickies-delete-all-sticky-files ()
  "Delete all files of stickies.
   Note: This function does not kill displayed sticky buffers."
  (interactive)
  (dolist (buffer (stickies-get-all-stickies-buffers))
    (stickies-delete-sticky-file buffer)))

(defun stickies-kill-sticky-and-delete-file (&optional buffer)
  "Kill a sticky and delete file."
  (interactive)
  (if (not buffer)
      (setq buffer (current-buffer)))
  (when (stickies-is-sticky-buffer buffer)
    (stickies-delete-sticky-file buffer)
    (stickies-kill-sticky buffer)))

(provide 'stickies)
;;; stickies.el ends here
