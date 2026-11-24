# The command line
@weight 2

bundle/cli: `x bundle COMMAND [ARG] [OPTIONS]`.

## what the main answers

### -V, an unknown option, no command, an unknown command

```bundle
(write (list (bundle-main (list "-V")) (bundle-main (list "--zap")) (bundle-main ())
             (bundle-main (list "frob"))))
```
---
    (0 2 2 2)

### install, list and remove, under --dir

```bundle
(def dir (spec-host!))
(def a (bundle-main (list "install" "app" "--dir" dir)))
(def b (bundle-main (list "list" "--dir" dir)))
(def c (bundle-main (list "remove" "dep" "-d" dir)))
(write (list a b c (installed dir)))
```
---
    (0 0 0 (("app" . "v1")))

### a failed install is status 1, a command given too much or too little 2

```bundle
(def dir (spec-host!))
(write (list (bundle-main (list "install" "nosuch" "--dir" dir))
             (bundle-main (list "install" "--dir" dir))
             (bundle-main (list "list" "extra" "--dir" dir))
             (bundle-main (list "remove" "--dir" dir))
             (bundle-main (list "remove" "app" "--dir" dir))))
```
---
    (1 2 2 2 1)
