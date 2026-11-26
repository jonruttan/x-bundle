# Check
@weight 1

bundle/check: the verdict on a spec run's output.

## the verdict

### a clean run: its total, nothing new, nothing fixed

```bundle
(write (spec-verdict "\x1b[1;32m.\x1b[0m\x1b[1;32m.\x1b[0m\n\n\x1b[1;32m2 tests, 0 failed, 0 pending\x1b[0m\n" ()))
```
---
    (2 () ())

### a failure not recorded is new; one recorded and passing is fixed

```bundle
(def out "\x1b[1;31mFAIL: a: one\n  expected: 1\n  got:      2\x1b[0m\nFAIL: a: two\nFAIL: a: one\n3 tests, 2 failed, 0 pending\n")
(write (list (spec-verdict out ())
             (spec-verdict out (list "a: one" "a: two"))
             (spec-verdict out (list "a: two" "a: gone"))))
```
---
    ((3 ("a: one" "a: two") ()) (3 () ()) (3 ("a: one") ("a: gone")))

### the last totals line counts, and a run with none has no total

```bundle
(write (list (spec-verdict "4 tests, 0 failed, 0 pending\n9 tests, 0 failed, 1 pending\n" ())
             (spec-verdict "sh: no such file\n" ())
             (spec-verdict "" ())))
```
---
    ((9 () ()) (() () ()) (() () ()))

## the list of known failures

### its lines, less the blank ones, the comments and the repeats

```bundle
(write (known-failures "# recorded debt\n\na: one\n  a: two  \na: one\n"))
```
---
    ("a: one" "a: two")
