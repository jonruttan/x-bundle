# Install, list, remove
@weight 2

bundle/install, against releases laid out under a directory.

## install

### by name: the bundle and the one it requires, at the release its row names

```bundle
(def dir (spec-host!))
(def path (install! "app" dir))
(write (list (str=? path (Str8 append dir "/app")) (installed dir)))
```
---
    (#t (("app" . "v1") ("dep" . "v2")))

### again: the requirement is installed at that release and left alone

```bundle
(def dir (spec-host!))
(install! "app" dir)
(File write-all (Str8 append dir "/dep/kept") "kept")
(install! "app" dir)
(write (list (File exists? (Str8 append dir "/dep/kept")) (installed dir)))
```
---
    (#t (("app" . "v1") ("dep" . "v2")))

### a requirement installed at another release is replaced

```bundle
(def dir (spec-host!))
(install! "dep" dir)
(def before (installed dir))
(install! "app" dir)
(write (list before (installed dir)))
```
---
    ((("dep" . "v3")) (("app" . "v1") ("dep" . "v2")))

### a requirement naming no repository: the index's, else jonruttan/x-NAME

```bundle
(def dir (spec-host!))
(install! "jonruttan/x-use" dir)
(def listed (installed dir))
(def dir (spec-host!))
(spec-index! "(bundle \"zzz\" \"o/zzz\")\n")
(install! "jonruttan/x-use" dir)
(write (list listed (installed dir)))
```
---
    ((("dep" . "v3") ("use" . "v1")) (("dep" . "v2") ("use" . "v1")))

### by reference: the latest release, with no index row read

```bundle
(def dir (spec-host!))
(spec-index! "(bundle \"zzz\" \"o/zzz\")\n")
(install! "alice/x-dep" dir)
(write (installed dir))
```
---
    (("dep" . "v3"))

### by the URL of a pin

```bundle
(def dir (spec-host!))
(install! (Str8 append "file://" spec-root "/host/alice/x-dep/releases/download/v2/bundle.pin.xon") dir)
(write (installed dir))
```
---
    (("dep" . "v2"))

### a name the index lacks, and an index that does not read

```bundle
(def dir (spec-host!))
(def a (spec-raise (fn (_) (install! "nosuch" dir))))
(spec-index! "(bundle \"b\" \"o/b\")\n(bundle \"a\" \"o/a\")\n")
(def b (spec-raise (fn (_) (install! "a" dir))))
(write (list (Str8 starts? "bundle: no bundle nosuch in the index at file://" a)
             (Str8 ends? "bundle: index is not sorted: a after b" b)
             (installed dir)))
```
---
    (#t #t ())

## remove

### an installed bundle goes, the others stay

```bundle
(def dir (spec-host!))
(install! "app" dir)
(remove! "app" dir)
(write (installed dir))
```
---
    (("dep" . "v2"))

### one that is not installed, and what is not a name

```bundle
(def dir (spec-host!))
(install! "dep" dir)
(write (list (Str8 starts? "bundle: app is not installed in " (spec-raise (fn (_) (remove! "app" dir))))
             (spec-raise (fn (_) (remove! "../dep" dir)))
             (spec-raise (fn (_) (remove! "" dir)))
             (installed dir)))
```
---
    (#t "bundle: not a bundle's name: ../dep" "bundle: not a bundle's name: " (("dep" . "v3")))

## install from a directory

### the declaration and lib/, no stamp, and what it requires

```bundle
(def dir (spec-host!))
(def path (install! (spec-source! "loc") dir))
(write (list (installed dir)
             (File exists? (Str8 append path "/lib/loc/m.x"))
             (File exists? (Str8 append path "/tests"))
             (File exists? (Str8 append path "/version"))))
```
---
    ((("dep" . "v2") ("loc")) #t #f #f)

### again replaces the earlier install whole

```bundle
(def dir (spec-host!))
(def src (spec-source! "loc"))
(def path (install! src dir))
(File write-all (Str8 append path "/stale") "stale")
(File write-all (Str8 append src "/lib/loc/n.x") "(module n)\n")
(install! src dir)
(write (list (File exists? (Str8 append path "/stale")) (File exists? (Str8 append path "/lib/loc/n.x"))))
```
---
    (#f #t)

### a directory with no bundle in it

```bundle
(def dir (spec-host!))
(spec-mkdirs (Str8 append spec-root "/empty"))
(write (list (Str8 starts? "bundle: no bundle.xon naming a bundle in /"
               (spec-raise (fn (_) (install! (Str8 append spec-root "/empty") dir))))
             (installed dir)))
```
---
    (#t ())
