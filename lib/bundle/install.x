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

; The reference a requirement is fetched from: the repository its row names,
; else the one the index lists under its name, else jonruttan/x-NAME. The
; index is read only for a row that names no repository.
(def %requirement-ref
  (fn (_ name repo dir)
    (if (null? repo)
      (let ((ref (index-ref name (%index dir))))
        (if (null? ref) (Str8 append "jonruttan/x-" name) ref))
      repo)))

; Every bundle in reqs, and what each requires in turn, into dir. A row's
; repository is the one %requirement-ref answers; its
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
                                (ref-pin-url (%requirement-ref name repo dir) version)
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

; path and everything under it.
(def %remove-tree!
  (fn (self path)
    (if (eq? (File ltype path) (lit dir))
      (do (List for-each (fn (_ e) (self (%join path e))) (File list-dir path))
          (File rmdir path))
      (File unlink path))))

; from's files and directories copied to to, which is made. Anything that is
; neither, a link among them, is left out.
(def %copy-tree!
  (fn (self from to)
    (do
      (File mkdir to)
      (List for-each
        (fn (_ e)
          (let ((kind (File ltype (%join from e))))
            (match
              ((eq? kind (lit dir)) (self (%join from e) (%join to e)))
              ((eq? kind (lit file)) (File copy (%join from e) (%join to e)))
              (#t ()))))
        (File list-dir from)))))

; A directory is what starts with "." or "/": a name has neither, and a
; reference starts with its owner.
(def %directory?
  (fn (_ what) (if (Str8 starts? "." what) #t (Str8 starts? "/" what))))

; The name the (name "NAME") row among forms declares, or nil.
(def %declared-name
  (fn (_ forms)
    (let ((row (List find (fn (_ f) (if (pair? f) (eq? (first f) (lit name)) #f)) forms)))
      (if (null? row) ()
        (if (pair? (rest row)) (if (str? (first (rest row))) (first (rest row)) ()) ())))))

; The paths the (payload "PATH" ...) rows among forms name, in order: what a
; bundle ships beside its declaration and lib/. A path is one name at the
; bundle's top, so nothing outside the bundle can be named, and not one the
; install writes itself.
(def %payload
  (fn (_ forms)
    (List flat-map
      (fn (_ f)
        (List map
          (fn (_ p)
            (match
              ((not (str? p)) (%bad "a payload row names paths as strings"))
              ((if (str=? p "") #t (if (Str8 includes? "/" p) #t (Str8 starts? "." p)))
                (%bad (Str8 append "not a path at the bundle's top: payload " p)))
              ((if (str=? p "bundle.xon") #t (if (str=? p "lib") #t (str=? p "version")))
                (%bad (Str8 append "payload names " p ", which every install carries or writes")))
              (#t p)))
          (rest f)))
      (List filter (fn (_ f) (if (pair? f) (eq? (first f) (lit payload)) #f)) forms))))

; The payload path name copied from the bundle in from to tmp: a directory
; whole, a file as it is. One the bundle declares and does not have is
; refused.
(def %copy-payload!
  (fn (_ from tmp name)
    (let ((kind (guard (_ ()) (File ltype (%join from name)))))
      (match
        ((eq? kind (lit dir)) (%copy-tree! (%join from name) (%join tmp name)))
        ((eq? kind (lit file)) (File copy (%join from name) (%join tmp name)))
        (#t (%bad (Str8 append "bundle.xon declares payload " name ", and " from " has no such file or directory")))))))

; The bundle in the directory from, installed to dir/NAME under the name its
; bundle.xon declares: the declaration, lib/ and the payload it declares,
; what a release's tarball carries, with no version stamp, since a directory
; is no release. The copy is whole before it replaces an earlier install.
; Answers dir/NAME.
(def %install-directory!
  (fn (_ from dir)
    (let ((name (%declared-name (%manifest from)))
          (payload (%payload (%manifest from))))
      (match
        ((null? name) (%bad (Str8 append "no bundle.xon naming a bundle in " from)))
        ((if (str=? name "") #t (if (Str8 includes? "/" name) #t (Str8 starts? "." name)))
          (%bad (Str8 append "not a bundle's name: " name)))
        (#t
          (let ((path (%join dir name))
                (tmp (%join dir (Str8 append "." name "." (Str8 str (Sys getpid)) ".tmp"))))
            (do
              (if (File exists? tmp) (%remove-tree! tmp) ())
              (File mkdir tmp)
              (File copy (%join from "bundle.xon") (%join tmp "bundle.xon"))
              (if (eq? (File ltype (%join from "lib")) (lit dir))
                (%copy-tree! (%join from "lib") (%join tmp "lib"))
                ())
              (guard (e (do (%remove-tree! tmp) (error (Err text e))))
                (List for-each (fn (_ p) (%copy-payload! from tmp p)) payload))
              (if (File exists? path) (%remove-tree! path) ())
              (File rename tmp path)
              (display "bundle: installed " name " from " from " to " path "\n")
              path)))))))

; Install what -- a name the index lists, a reference, the URL of a
; bundle.pin.xon, or a directory holding a bundle -- under dir, then every
; bundle it requires. Answers the directory it was installed to.
(def install!
  (fn (_ what dir)
    (do
      (%mkdirs! dir)
      (let ((path (if (%directory? what)
                    (%install-directory! what dir)
                    (Pin install (%pin-url what dir) dir))))
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
