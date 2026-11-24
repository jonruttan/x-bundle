# The index
@weight 1

bundle/index: the rows of index.xon, and a reference's address.

## rows

### a name and a reference a row, comments passed over

```bundle
(write (index-rows "; official\n(bundle \"gfx\" \"jonruttan/x-lib-gfx\")\n(bundle \"zed\" \"gitlab.com/alice/x-zed\")\n"))
```
---
    (("gfx" . "jonruttan/x-lib-gfx") ("zed" . "gitlab.com/alice/x-zed"))

### a name's reference, nil for one the index lacks

```bundle
(def rows (index-rows "(bundle \"gfx\" \"jonruttan/x-lib-gfx\")\n"))
(write (list (index-ref "gfx" rows) (index-ref "nope" rows)))
```
---
    ("jonruttan/x-lib-gfx" ())

### out of order, and a name twice

```bundle
(write (list (spec-raise (fn (_) (index-rows "(bundle \"b\" \"o/b\")\n(bundle \"a\" \"o/a\")\n")))
             (spec-raise (fn (_) (index-rows "(bundle \"a\" \"o/a\")\n(bundle \"a\" \"o/b\")\n")))))
```
---
    ("bundle: index is not sorted: a after b" "bundle: index names a bundle twice: a")

### a form that is not a row, a name that is not bare, a reference that is not one

```bundle
(write (list (spec-raise (fn (_) (index-rows "(lib \"a\" \"o/a\")\n")))
             (spec-raise (fn (_) (index-rows "(bundle \"alice/a\" \"o/a\")\n")))
             (spec-raise (fn (_) (index-rows "(bundle \"a\" \"x-a\")\n")))
             (spec-raise (fn (_) (index-rows "(bundle \"a\" \"o/a\" \"v1\")\n")))))
```
---
    ("bundle: unknown form in the index: lib" "bundle: index name is not bare: alice/a" "bundle: index reference of a is not OWNER/REPO or DOMAIN/OWNER/REPO: x-a" "bundle: index row has more than a name and a reference: a")

### this repository's own index reads

```bundle
(write (> (List length (index-read (Str8 append (Bundle root "bundle") "/index.xon"))) 0))
```
---
    #t

## references

### OWNER/REPO, a domain first, and what is neither

```bundle
(write (list (ref-parts "alice/x-foo") (ref-parts "gitlab.com/alice/x-foo") (ref-parts "foo")
             (ref-parts "a/b/c") (ref-parts "a//b") (ref-parts "a/b/c/d")))
```
---
    (("alice" "x-foo") ("gitlab.com" "alice" "x-foo") () () () ())

### the latest release's pin, a named release's, github.com spelled out

```bundle
(Sys setenv "X_BUNDLE_HOST" "")
(write (list (ref-pin-url "alice/x-foo" ())
             (ref-pin-url "alice/x-foo" "v1.2.0")
             (ref-pin-url "github.com/alice/x-foo" ())))
```
---
    ("https://github.com/alice/x-foo/releases/latest/download/bundle.pin.xon" "https://github.com/alice/x-foo/releases/download/v1.2.0/bundle.pin.xon" "https://github.com/alice/x-foo/releases/latest/download/bundle.pin.xon")

### X_BUNDLE_HOST in place of github.com, and a host that is not known

```bundle
(Sys setenv "X_BUNDLE_HOST" "file:///srv/mirror")
(write (list (ref-pin-url "alice/x-foo" ())
             (spec-raise (fn (_) (ref-pin-url "gitlab.com/alice/x-foo" ())))))
```
---
    ("file:///srv/mirror/alice/x-foo/releases/latest/download/bundle.pin.xon" "bundle: cannot install gitlab.com/alice/x-foo: only github.com references install by name; give the URL of its bundle.pin.xon")
