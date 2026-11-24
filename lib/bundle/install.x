; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/install.x -- install, list and remove
;
; @description Installs a bundle and every bundle it requires, lists the
;   installed ones, and removes one.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; One bundle is acquired by the platform's (Pin install PIN-URL DIR): the pin
; is read, the tarball held to its digest, unpacked, and moved to DIR/NAME
; once whole. This module finds the pin (through the index for a name,
; through the host for a reference) and follows the (requires-bundle ...)
; rows of what it installed.
(module bundle/install)

(import x/sys/file)
(import x/sys/posix)
(import x/sys/bundle)
(import x/codec/xon)
(import x/type/path)
(import x/type/err)
(import x/tool/pin)
(import bundle/index index-url index-rows index-ref ref-pin-url)

(def %bad (fn (_ text) (error (Str8 append "bundle: " text))))

(def %join (fn (_ dir name) (Str8 append dir "/" name)))

; The directory bundles are installed under: the one given, else the one
; this session's x reads them from.
(def bundles-dir
  (fn (_ given)
    (let ((dir (if (null? given) (Bundle dir) given)))
      (match
        ((null? dir) (%bad "no bundles directory: this x names none, give --dir DIR"))
        ((if (> (Str8 length dir) 1) (Str8 ends? "/" dir) #f) (Str8 sub 0 (- (Str8 length dir) 1) dir))
        (#t dir)))))

; url's body written to path: a file:// address is copied, any other read
; off Http a piece at a time. Http brings TLS, so it is imported on the
; first fetch.
(def %fetch!
  (fn (_ url path)
    (if (Str8 starts? "file://" url)
      (File copy (Str8 sub 7 (- (Str8 length url) 7) url) path)
      (do
        (import x/net/http)
        (let ((s (Http open "GET" url () ())))
          (if (not (= (s status) 200))
            (do (Http close s)
                (%bad (Str8 append "the index at " url " answered " (Str8 str (s status)))))
            (let ((fd (File open path (list (lit wronly) (lit creat) (lit trunc)))))
              (do
                (let loop ((r (Http read s 65536)))
                  (if (null? r) ()
                    (do (File write fd (first r) (rest r))
                        (loop (Http read s 65536)))))
                (File close fd)
                (Http close s)))))))))

; The index's rows, fetched fresh into dir.
(def %index
  (fn (_ dir)
    (let ((tmp (%join dir (Str8 append ".index." (Str8 str (Sys getpid)) ".xon"))))
      (guard (e (do (guard (_ ()) (File unlink tmp))
                    (%bad (Str8 append "cannot read the index at " (index-url) ": " (Err text e)))))
        (do
          (%fetch! (index-url) tmp)
          (let ((rows (index-rows (File read-all tmp))))
            (do (File unlink tmp)
                rows)))))))

; What install was given -> the address of a bundle.pin.xon: a URL as it is,
; a reference through its host, a name through the index.
(def %pin-url
  (fn (_ what dir)
    (match
      ((Str8 includes? "://" what) what)
      ((Str8 includes? "/" what) (ref-pin-url what ()))
      (#t (let ((ref (index-ref what (%index dir))))
            (if (null? ref)
              (%bad (Str8 append "no bundle " what " in the index at " (index-url)))
              (do (display "bundle: " what " is " ref "\n")
                  (ref-pin-url ref ()))))))))

; The forms of the bundle.xon in path, or nil where there is none.
(def %manifest
  (fn (_ path)
    (guard (_ ()) (Xon parse (File read-all (%join path "bundle.xon"))))))

; The (requires-bundle "NAME" ["VERSION" ["OWNER/REPO"]]) rows among forms
; -> ((NAME VERSION REPO) ...), an absent part nil.
(def %requires
  (fn (_ forms)
    (List map
      (fn (_ f)
        (let ((args (rest f)))
          (list (first args)
                (if (pair? (rest args)) (first (rest args)) ())
                (if (pair? (rest args)) (if (pair? (rest (rest args))) (first (rest (rest args))) ()) ()))))
      (List filter (fn (_ f) (if (pair? f) (eq? (first f) (lit requires-bundle)) #f)) forms))))

; The release the bundle installed at path reports in its version stamp, or
; nil.
(def %version
  (fn (_ path)
    (guard (_ ()) (Str8 trim (File read-all (%join path "version"))))))

; Every bundle in reqs, and what each requires in turn, into dir. A row's
; repository is used as written, jonruttan/x-NAME when it names none; its
; version is that release, the latest when it names none. One installed at
; the version asked for (at any, when none is asked) is left alone; at
; another, it is replaced. seen holds the names this install has handled,
; which also ends a cycle; the answer is seen with reqs added.
(def %install-requires!
  (fn (self reqs dir seen)
    (if (null? reqs) seen
      (let ((name (first (first reqs)))
            (version (first (rest (first reqs))))
            (repo (first (rest (rest (first reqs))))))
        (self (rest reqs) dir
          (if (List any? (fn (_ s) (str=? s name)) seen) seen
            (let ((have (%version (%join dir name))))
              (if (if (null? have) #f (if (null? version) #t (str=? have version)))
                (do (display "bundle: " name " " have " already installed\n")
                    (pair name seen))
                (do
                  (if (null? have) ()
                    (display "bundle: " name " " have " installed, " version " required: replacing it\n"))
                  (let ((path (Pin install
                                (ref-pin-url (if (null? repo) (Str8 append "jonruttan/x-" name) repo) version)
                                dir)))
                    (do
                      (if (str=? (Path basename path) name) ()
                        (%bad (Str8 append "required " name ", installed a bundle calling itself "
                                (Path basename path))))
                      (self (%requires (%manifest path)) dir (pair name seen)))))))))))))

; dir and every directory above it that is missing.
(def %mkdirs!
  (fn (self dir)
    (if (File exists? dir) ()
      (do (self (Path dirname dir))
          (File mkdir dir)))))

; Install what -- a name the index lists, a reference, or the URL of a
; bundle.pin.xon -- under dir, then every bundle it requires. Answers the
; directory it was installed to.
(def install!
  (fn (_ what dir)
    (do
      (%mkdirs! dir)
      (let ((path (Pin install (%pin-url what dir) dir)))
        (do (%install-requires! (%requires (%manifest path)) dir (list (Path basename path)))
            path)))))

; The bundles installed directly under dir -> ((NAME . VERSION) ...) sorted
; by name, VERSION nil for one with no stamp (installed from a checkout).
(def installed
  (fn (_ dir)
    (List sort (fn (_ a b) (Str8 <? (first a) (first b)))
      (List flat-map
        (fn (_ e)
          (if (if (Str8 starts? "." e) #t (null? (%manifest (%join dir e)))) ()
            (list (pair e (%version (%join dir e))))))
        (guard (_ ()) (File list-dir dir))))))

; path and everything under it.
(def %remove-tree!
  (fn (self path)
    (if (eq? (File ltype path) (lit dir))
      (do (List for-each (fn (_ e) (self (%join path e))) (File list-dir path))
          (File rmdir path))
      (File unlink path))))

; Remove the bundle installed as name under dir. Answers the directory
; removed.
(def remove!
  (fn (_ name dir)
    (let ((path (%join dir name)))
      (match
        ((if (str=? name "") #t (if (Str8 includes? "/" name) #t (Str8 starts? "." name)))
          (%bad (Str8 append "not a bundle's name: " name)))
        ((null? (%manifest path)) (%bad (Str8 append name " is not installed in " dir)))
        (#t (do (%remove-tree! path) path))))))

(provide bundle/install bundles-dir install! installed remove!)
