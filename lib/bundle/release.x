; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/release.x -- a bundle's release: its tarball and its pin
;
; @description Packs a bundle into the tarball an install unpacks, digests
;   it, and writes the bundle.pin.xon that names it.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Three files are written into the directory out, named for the repository:
;
;   REPO-TAG.tar.gz          the bundle
;   REPO-TAG.tar.gz.sha256   its digest, as shasum prints it
;   bundle.pin.xon           the bundle's name, the tag, the digest and the
;                            URL the tarball is published at
;
; The tarball holds what runs: bundle.xon, lib/, the payload bundle.xon
; declares, and LICENSE and README.md where the bundle has them, under one
; directory REPO-TAG/, with a file `version` holding the tag. It is packed
; from the directory as it is; a name starting with "." and anything that is
; neither a file nor a directory are left out. Members are sorted and carry
; no time or owner, so the same files give the same bytes.
;
; The repository is the (repository "OWNER/REPO") row of bundle.xon: a
; bundle's name says nothing of where it is kept. The tarball's URL is that
; repository's release for the tag, under X_BUNDLE_HOST where it is set,
; as an install reads it.
(module bundle/release)

(import x/sys/file)
(import x/sys/posix)
(import x/type/assoc)
(import x/type/err)
(import x/codec/bytes)
(import x/codec/gzip)
(import x/codec/tar)
(import x/codec/sha256)
(import bundle/index ref-parts)
(import bundle/install bundle-manifest declared-name payload-paths mkdirs!)

(def %bad (fn (_ text) (error (Str8 append "bundle: " text))))

(def %join (fn (_ dir name) (Str8 append dir "/" name)))

; The string a (key "VALUE") row among forms names, or nil.
(def %row
  (fn (_ key forms)
    (let ((row (List find (fn (_ f) (if (pair? f) (eq? (first f) key) #f)) forms)))
      (if (null? row) ()
        (if (pair? (rest row)) (if (str? (first (rest row))) (first (rest row)) ()) ())))))

; The OWNER/REPO the (repository ...) row names.
(def %repository
  (fn (_ forms)
    (let ((repo (%row (lit repository) forms)))
      (match
        ((null? repo) (%bad "bundle.xon has no (repository \"OWNER/REPO\") row: add the one it is kept in"))
        ((not (= (List length (ref-parts repo)) 2)) (%bad (Str8 append "not an OWNER/REPO: " repo)))
        (#t repo)))))

; A tag is one name a URL can carry.
(def %tag?
  (fn (_ tag)
    (if (str=? tag "") #f
      (if (Str8 starts? "." tag) #f
        (not (List any? (fn (_ c) (Str8 includes? c tag)) (list "/" " " "\"" "\\")))))))

; The region r, written whole to fd.
(def %write!
  (fn (_ fd r)
    (let ((n (Bytes length r)))
      (if (= n 0) ()
        (let ((b (if (= (first (rest r)) 0) (first r) (first (Bytes copy r)))))
          (if (= (File write fd b n) n) ()
            (%bad "a short write to the tarball")))))))

; The region r put through the member g, its output written to fd.
(def %feed!
  (fn (_ g fd r final)
    (%write! fd (Gzip feed g (first r) (first (rest r)) (Bytes length r) final))))

; The members under from, as (PATH . SOURCE) with PATH relative to the
; tarball's top, a directory's SOURCE nil, in the order they are written.
(def %tree
  (fn (self from path)
    (pair (pair path ())
      (List flat-map
        (fn (_ e)
          (let ((kind (File ltype (%join from e))))
            (match
              ((Str8 starts? "." e) ())
              ((eq? kind (lit dir)) (self (%join from e) (%join path e)))
              ((eq? kind (lit file)) (list (pair (%join path e) (%join from e))))
              (#t ()))))
        (List sort (fn (_ a b) (Str8 <? a b)) (File list-dir from))))))

; One top-level path of the bundle in dir, as members under stem.
(def %members-of
  (fn (_ dir stem name)
    (let ((kind (guard (_ ()) (File ltype (%join dir name)))))
      (match
        ((eq? kind (lit dir)) (%tree (%join dir name) (%join stem name)))
        ((eq? kind (lit file)) (list (pair (%join stem name) (%join dir name))))
        (#t (%bad (Str8 append "bundle.xon declares payload " name ", and " dir " has no such file or directory")))))))

; The file at source as one member path: its header, its bytes a piece at a
; time, its padding.
(def %put-file!
  (fn (_ g fd buf path source)
    (let ((size (Assoc get (lit size) (File stat source)))
          (in (File open source (lit rdonly))))
      (do
        (%feed! g fd (Tar header path size 420 0 (lit file)) #f)
        (let loop ((n (File read in buf 65536)))
          (if (> n 0)
            (do (%feed! g fd (list buf 0 n) #f)
                (loop (File read in buf 65536)))
            ()))
        (File close in)
        (%feed! g fd (Tar padding size) #f)))))

; The sha256 digest of the file at path, as hex.
(def %digest
  (fn (_ path)
    (Sha256 hex-n (File read-all path) (Assoc get (lit size) (File stat path)))))

; The release tag of the bundle in dir, written into out: the tarball, its
; digest and its pin. Answers the paths written, after saying each path the
; tarball holds.
(def release!
  (fn (_ dir tag out)
    (let ((forms (bundle-manifest dir)))
      (let ((name (declared-name forms)))
        (match
          ((null? name) (%bad (Str8 append "no bundle.xon naming a bundle in " dir)))
          ((not (%tag? tag)) (%bad (Str8 append "not a tag: " tag)))
          ((not (eq? (guard (_ ()) (File ltype (%join dir (Str8 append "lib/" name)))) (lit dir)))
            (%bad (Str8 append "no lib/" name " in " dir ": a bundle's modules are under lib/, in a directory of its name")))
          (#t
            (let ((repo (%repository forms))
                  (payload (payload-paths forms)))
              (let ((stem (Str8 append (first (rest (ref-parts repo))) "-" tag))
                    (host (let ((h (Sys getenv "X_BUNDLE_HOST"))) (if (null? h) "https://github.com" (if (str=? h "") "https://github.com" h)))))
                (let ((tarball (%join out (Str8 append stem ".tar.gz")))
                      (members
                        (List flat-map (fn (_ p) (%members-of dir stem p))
                          (List append
                            (list "bundle.xon" "lib")
                            (List filter (fn (_ p) (File exists? (%join dir p))) (list "LICENSE" "README.md"))
                            (List filter (fn (_ p) (not (List any? (fn (_ q) (str=? p q)) (list "LICENSE" "README.md")))) payload)))))
                  (do
                    (mkdirs! out)
                    (let ((fd (File open tarball (list (lit wronly) (lit creat) (lit trunc))))
                          (g (Gzip stream))
                          (buf (str-make 65536)))
                      (do
                        (%feed! g fd (Tar header stem 0 493 0 (lit dir)) #f)
                        (List for-each
                          (fn (_ m)
                            (do
                              (display (first m) "\n")
                              (if (null? (rest m))
                                (%feed! g fd (Tar header (first m) 0 493 0 (lit dir)) #f)
                                (%put-file! g fd buf (first m) (rest m)))))
                          members)
                        (display (%join stem "version") "\n")
                        (let ((v (Str8 append tag "\n")))
                          (do (%feed! g fd (Tar header (%join stem "version") (Str8 length v) 420 0 (lit file)) #f)
                              (%feed! g fd (list v 0 (Str8 length v)) #f)
                              (%feed! g fd (Tar padding (Str8 length v)) #f)))
                        (%feed! g fd (Tar end) #t)
                        (File close fd)))
                    (let ((dg (%digest tarball))
                          (sums (%join out (Str8 append stem ".tar.gz.sha256")))
                          (pin (%join out "bundle.pin.xon")))
                      (do
                        (File write-all sums (Str8 append dg "  " stem ".tar.gz\n"))
                        (File write-all pin
                          (Str8 append
                            "(name \"" name "\")\n"
                            "(release \"" tag "\")\n"
                            "(bundle \"sha256:" dg "\" \"" host "/" repo "/releases/download/" tag "/" stem ".tar.gz\")\n"
                            (if (str=? host "https://github.com")
                              (Str8 append "(source \"https://github.com/" repo ".git\")\n")
                              "")))
                        (list tarball sums pin))))))))))))))

(provide bundle/release release!)
