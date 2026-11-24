; # x-bundle -- the bundle tool and index on x-lang
;
; ## tools/index-install.x -- every row of the index installs
;
; @description Installs each bundle index.xon lists, by its name, into a
;   directory of its own, and fails when one does not install or installs
;   under another name.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Run from x with this checkout's parent as X_BUNDLE_DIR, so the imports
; below arm it:
;
;     X_BUNDLE_DIR=/path/to/x-bundle/.. x -q -f tools/index-install.x
;
; The index read is this checkout's, not the published one: a pull request
; that adds a row is held to that row. Each install is the real one, over
; the network, from the row's latest release.
(import x/sys/file)
(import x/sys/posix)
(import x/sys/bundle)
(import x/type/path)
(import x/type/err)
(import bundle/index index-read)
(import bundle/install install!)

(def %index-path (Str8 append (Bundle root "bundle") "/index.xon"))
(def %work (Str8 append "/tmp/x-bundle-index." (Str8 str (Sys getpid))))

; What is wrong with installing name, or nil.
(def %row-fault
  (fn (_ name)
    (guard (e (Err text e))
      (let ((path (install! name (Str8 append %work "/" name))))
        (if (str=? (Path basename path) name) ()
          (Str8 append "installed a bundle calling itself " (Path basename path)))))))

(Sys setenv "X_BUNDLE_INDEX" (Str8 append "file://" %index-path))
(def %faults
  (List flat-map
    (fn (_ row)
      (let ((fault (%row-fault (first row))))
        (if (null? fault)
          (do (display "index: " (first row) " installs from " (rest row) "\n") ())
          (do (display "index: " (first row) " (" (rest row) ") does not install: " fault "\n")
              (list (first row))))))
    (index-read %index-path)))
(Sys exit (if (null? %faults) 0 1))
