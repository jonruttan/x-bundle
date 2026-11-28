# Release
@weight 2

bundle/release, writing a bundle's checkout as a release laid out under the
spec host.

## release

### what it writes installs, by the URL of its pin

```bundle
(def dir (spec-host!))
(def src (spec-release-source! "loc"))
(def out (Str8 append spec-root "/host/o/x-loc/releases/download/v1"))
(def wrote (release! src "v1" out))
(def path (install! (Str8 append "file://" out "/bundle.pin.xon") dir))
(write (list (List map (fn (_ p) (Str8 sub (+ 1 (Str8 length out)) (- (Str8 length p) (+ 1 (Str8 length out))) p)) wrote)
             (installed dir)
             (File exists? (Str8 append path "/lib/loc/m.x"))
             (File read-all (Str8 append path "/README.md"))
             (File exists? (Str8 append path "/lib/loc/.swap"))
             (File exists? (Str8 append path "/tests"))))
```
---
    (("x-loc-v1.tar.gz" "x-loc-v1.tar.gz.sha256" "bundle.pin.xon") (("dep" . "v2") ("loc" . "v1")) #t "# loc\n" #f #f)

### the pin names the tarball by its digest, and the same files give the same bytes

```bundle
(spec-host!)
(def src (spec-release-source! "loc"))
(def a (Str8 append spec-root "/out-a"))
(def b (Str8 append spec-root "/out-b"))
(release! src "v1" a)
(release! src "v1" b)
(def sums (File read-all (Str8 append a "/x-loc-v1.tar.gz.sha256")))
(def dg (Str8 sub 0 64 sums))
(write (list (str=? sums (File read-all (Str8 append b "/x-loc-v1.tar.gz.sha256")))
             (Str8 ends? "  x-loc-v1.tar.gz\n" sums)
             (Str8 includes? (Str8 append "(bundle \"sha256:" dg "\" \"file://" spec-root "/host/o/x-loc/releases/download/v1/x-loc-v1.tar.gz\")")
               (File read-all (Str8 append a "/bundle.pin.xon")))))
```
---
    (#t #t #t)

### on github.com the pin names the source too

```bundle
(spec-host!)
(def src (spec-release-source! "loc"))
(Sys setenv "X_BUNDLE_HOST" "")
(def out (Str8 append spec-root "/out-gh"))
(release! src "v1" out)
(def pin (File read-all (Str8 append out "/bundle.pin.xon")))
(write (list (Str8 includes? "\"https://github.com/o/x-loc/releases/download/v1/x-loc-v1.tar.gz\")\n" pin)
             (Str8 ends? "(source \"https://github.com/o/x-loc.git\")\n" pin)))
```
---
    (#t #t)

### what is not a release is refused

```bundle
(spec-host!)
(def src (spec-release-source! "loc"))
(def out (Str8 append spec-root "/out-bad"))
(def bad-tag (spec-raise (fn (_) (release! src "v/1" out))))
(File write-all (Str8 append src "/bundle.xon") "(name \"loc\")\n(dialect he)\n")
(def no-repo (spec-raise (fn (_) (release! src "v1" out))))
(File write-all (Str8 append src "/bundle.xon") "(name \"loc\")\n(repository \"o\")\n")
(def bad-repo (spec-raise (fn (_) (release! src "v1" out))))
(File write-all (Str8 append src "/bundle.xon") "(name \"other\")\n(repository \"o/x-loc\")\n")
(def no-lib (spec-raise (fn (_) (release! src "v1" out))))
(write (list bad-tag no-repo bad-repo (Str8 starts? "bundle: no lib/other in " no-lib) (File exists? out)))
```
---
    ("bundle: not a tag: v/1" "bundle: bundle.xon has no (repository \"OWNER/REPO\") row: add the one it is kept in" "bundle: not an OWNER/REPO: o" #t #f)
