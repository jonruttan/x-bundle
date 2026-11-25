# New
@weight 2

bundle/new: the four files a bundle starts from.

## the files

### an application: a declaration with an entry, the entry, a spec, a README

```bundle
(spec-clear! (Str8 append spec-root "/new"))
(spec-mkdirs (Str8 append spec-root "/new"))
(def dir (new! "my-app" #f (Str8 append spec-root "/new") "v0.62.0"))
(def at (fn (_ f) (File read-all (Str8 append dir "/" f))))
(write (list (Str8 ends? "/new/my-app" dir)
             (at "bundle.xon")
             (Str8 includes? "(module my-app/run)" (at "lib/my-app/run.x"))
             (Str8 includes? "(provide my-app/run main my-app-hello)" (at "lib/my-app/run.x"))
             (Str8 includes? "(import my-app/run my-app-hello)" (at "tests/specs/my-app.spec.md"))
             (Str8 includes? "x my-app\n" (at "README.md"))))
```
---
    (#t "; bundle.xon -- what this bundle is.\n\n(name \"my-app\")\n\n(dialect he)\n\n(requires-release \"v0.62.0\")\n\n(entry run)\n" #t #t #t #t)

### a library: no entry, a module of its own name

```bundle
(spec-clear! (Str8 append spec-root "/new"))
(spec-mkdirs (Str8 append spec-root "/new"))
(def dir (new! "kit" #t (Str8 append spec-root "/new") "v0.62.0"))
(def at (fn (_ f) (File read-all (Str8 append dir "/" f))))
(write (list (Str8 includes? "(entry" (at "bundle.xon"))
             (File exists? (Str8 append dir "/lib/kit/run.x"))
             (Str8 includes? "(provide kit/kit kit-hello)" (at "lib/kit/kit.x"))
             (Str8 includes? "(import kit/kit kit-hello)" (at "README.md"))))
```
---
    (#f #f #t #t)

### what it starts installs, and its module says what its spec expects

```bundle
(def bundles (spec-host!))
(spec-clear! (Str8 append spec-root "/new"))
(spec-mkdirs (Str8 append spec-root "/new"))
(def dir (new! "kit" #t (Str8 append spec-root "/new") ()))
(def path (install! dir bundles))
(import-path! (Str8 append path "/lib"))
(import kit/kit kit-hello)
(write (list (installed bundles) (kit-hello) (Str8 includes? "requires-release" (File read-all (Str8 append dir "/bundle.xon")))))
```
---
    ((("kit")) "hello from kit" #f)

## refusals

### a name that is not one, and a directory already there

```bundle
(spec-clear! (Str8 append spec-root "/new"))
(spec-mkdirs (Str8 append spec-root "/new/taken"))
(def in (Str8 append spec-root "/new"))
(write (list (spec-raise (fn (_) (new! "My_App" #f in ())))
             (spec-raise (fn (_) (new! "9lives" #f in ())))
             (spec-raise (fn (_) (new! "" #f in ())))
             (Str8 ends? "/new/taken is already there" (spec-raise (fn (_) (new! "taken" #f in ()))))
             (File list-dir in)))
```
---
    ("bundle: not a bundle's name: My_App (lower-case letters, digits and hyphens, a letter first)" "bundle: not a bundle's name: 9lives (lower-case letters, digits and hyphens, a letter first)" "bundle: not a bundle's name:  (lower-case letters, digits and hyphens, a letter first)" #t ("taken"))

## the release a new bundle declares

### a stamp past a release names the release; any other is as written

```bundle
(write (list (release-tag "v0.62.0") (release-tag "v0.62.0-29-g43df8c6b") (release-tag "v1.0.0-rc1")
             (release-tag "v1.0.0-rc1-3-gabc1234") (release-tag "dev-go")))
```
---
    ("v0.62.0" "v0.62.0" "v1.0.0-rc1" "v1.0.0-rc1" "dev-go")
