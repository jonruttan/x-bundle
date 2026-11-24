; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/index.x -- the index and the references it holds
;
; @description Reads index.xon and turns a reference into the address of a
;   release's bundle.pin.xon.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The index is one (bundle "NAME" "REFERENCE") row a bundle, sorted by name.
; A name is bare; a reference is OWNER/REPO on github.com, or
; DOMAIN/OWNER/REPO. The index holds no versions: a release changes nothing
; here.
(module bundle/index)

(import x/sys/file)
(import x/sys/posix)
(import x/codec/xon)

(def %env
  (fn (_ var default)
    (let ((v (Sys getenv var)))
      (if (null? v) default (if (str=? v "") default v)))))

(def %bad (fn (_ text) (error (Str8 append "bundle: " text))))

; Where the index is read from: X_BUNDLE_INDEX (a URL or a file:// path),
; else this repository's own.
(def index-url
  (fn (_) (%env "X_BUNDLE_INDEX" "https://raw.githubusercontent.com/jonruttan/x-bundle/main/index.xon")))

; ref split at "/", or nil when a part is empty.
(def %parts
  (fn (_ ref)
    (let go ((s ref) (acc ()))
      (let ((i (Str8 index-of "/" s)))
        (match
          ((null? i) (if (str=? s "") () (List reverse (pair s acc))))
          ((= i 0) ())
          (#t (go (Str8 sub (+ i 1) (- (Str8 length s) (+ i 1)) s)
                  (pair (Str8 sub 0 i s) acc))))))))

; A reference's parts, (OWNER REPO) or (DOMAIN OWNER REPO), a domain being
; the part with a dot; nil for anything else.
(def ref-parts
  (fn (_ ref)
    (let ((parts (%parts ref)))
      (match
        ((= (List length parts) 2) parts)
        ((if (= (List length parts) 3) (Str8 includes? "." (first parts)) #f) parts)
        (#t ())))))

; The address of the bundle.pin.xon a reference's release VERSION publishes,
; its latest release's when version is nil. OWNER/REPO sits under
; X_BUNDLE_HOST, else https://github.com. The address of a latest release
; differs a host, and github.com's is the one known.
(def ref-pin-url
  (fn (_ ref version)
    (let ((parts (ref-parts ref)))
      (match
        ((null? parts) (%bad (Str8 append "not a reference, OWNER/REPO or DOMAIN/OWNER/REPO: " ref)))
        ((if (= (List length parts) 3) (not (str=? (first parts) "github.com")) #f)
          (%bad (Str8 append "cannot install " ref
                  ": only github.com references install by name; give the URL of its bundle.pin.xon")))
        (#t
          (Str8 append
            (if (= (List length parts) 2) (%env "X_BUNDLE_HOST" "https://github.com") "https://github.com")
            "/"
            (if (= (List length parts) 2) ref
              (Str8 append (first (rest parts)) "/" (first (rest (rest parts)))))
            (if (null? version) "/releases/latest/download/bundle.pin.xon"
              (Str8 append "/releases/download/" version "/bundle.pin.xon"))))))))

; One row's (NAME . REFERENCE), or a raise naming what is wrong with it.
(def %row
  (fn (_ form)
    (match
      ((not (pair? form)) (%bad "index row is not a list"))
      ((not (eq? (first form) (lit bundle)))
        (%bad (if (symbol? (first form))
                (Str8 append "unknown form in the index: " (symbol->str (first form)))
                "index row does not start with bundle")))
      ((not (pair? (rest form))) (%bad "index row needs a name and a reference"))
      ((not (str? (first (rest form)))) (%bad "index row needs a name string"))
      (#t
        (let ((name (first (rest form))) (more (rest (rest form))))
          (match
            ((str=? name "") (%bad "index name is empty"))
            ((Str8 includes? "/" name) (%bad (Str8 append "index name is not bare: " name)))
            ((not (pair? more)) (%bad (Str8 append "index row has no reference: " name)))
            ((not (str? (first more))) (%bad (Str8 append "index reference is not a string: " name)))
            ((not (null? (rest more)))
              (%bad (Str8 append "index row has more than a name and a reference: " name)))
            ((null? (ref-parts (first more)))
              (%bad (Str8 append "index reference of " name
                      " is not OWNER/REPO or DOMAIN/OWNER/REPO: " (first more))))
            (#t (pair name (first more)))))))))

; The index's text -> ((NAME . REFERENCE) ...). Closed vocabulary, and names
; strictly ascending, so each appears once: any other file is a raise.
(def index-rows
  (fn (_ text)
    (let go ((forms (Xon parse text)) (prev ()) (acc ()))
      (if (null? forms) (List reverse acc)
        (let ((row (%row (first forms))))
          (match
            ((null? prev) (go (rest forms) (first row) (pair row acc)))
            ((Str8 <? prev (first row)) (go (rest forms) (first row) (pair row acc)))
            ((str=? prev (first row)) (%bad (Str8 append "index names a bundle twice: " prev)))
            (#t (%bad (Str8 append "index is not sorted: " (first row) " after " prev)))))))))

; The rows of the index file at path.
(def index-read (fn (_ path) (index-rows (File read-all path))))

; name's reference in rows, or nil.
(def index-ref
  (fn (_ name rows)
    (let ((row (List find (fn (_ r) (str=? (first r) name)) rows)))
      (if (null? row) () (rest row)))))

(provide bundle/index index-url index-rows index-read index-ref ref-parts ref-pin-url)
