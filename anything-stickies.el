;;; anything-stickies.el --- Integration of stickies.el into anything.el

;; Copyright (C) 2009  KOSAKA Tomohiko

;; Author: KOSAKA Tomohiko <tomohiko.kosaka@gmail.com>
;; Keywords: stickies, anything

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
;; This file provides the anything interface for stickies.

;;; Installation:
;;
;; 1. Put anything-stickies.el into a directory that 
;; Emacs recognizes as a part of `load-path'.
;; You can also byte-compile the file.
;; 
;; 2 . Put the following into your init file (.emacs.el):
;;
;; (require 'anything-stickies)
;;
;; Then you can access stickies by anything. Enjoy!

;;; Code:

(require 'anything)
(require 'stickies)

(defvar anything-c-source-stickies
  '((name . "Stickies")
    (candidates . (lambda ()
                    (mapcar 'buffer-name
                            (stickies-get-all-stickies-buffers)
                    )))
    (action . (("Move to the sticky frame" . (lambda (candidate)
                                               (switch-to-buffer-other-frame (get-buffer candidate))))
               ("Kill the sticky" . (lambda (candidate)
                                      (stickies-kill-sticky (get-buffer candidate))))
               ("Delete the sticky file" . (lambda (candidate)
                                             (if (y-or-n-p "Delete the sticky file?")
                                                 (stickies-delete-sticky-file (get-buffer candidate)))))
               ("Kill and delete the sticky" . (lambda (candidate)
                                              (if (y-or-n-p "Kill and Delete the sticky?")
                                                  (stickies-kill-sticky-and-delete-file (get-buffer candidate)))))
               ("Save the sticky" . (lambda (candidate)
                                      (stickies-save-sticky (get-buffer candidate))))
               ("Save the sticky and kill" . (lambda (candidate)
                                               (stickies-save-sticky (get-buffer candidate))
                                               (stickies-kill-sticky (get-buffer candidate))))))))

(provide 'anything-stickies)
;;; anything-stickies.el ends here
