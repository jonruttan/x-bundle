; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/check.x -- a bundle's checks
;
; @description Runs what a bundle is held to: one meaning a global name, its
;   specs, the linter and its documentation's examples.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The checks themselves are the platform's: the spec runner under its
; tests/, and the bundle kit under its tools/bundle-kit. They are shell
; today, and this runs them as children; a bundle carries no copy of them
; and no shim to reach them. What is decided here is the verdict on the
; specs: the tests that fail are held to tests/contract/known-failures.txt,
; an empty list for a bundle with none.
(module bundle/check)

(import x/sys/file)
(import x/sys/posix)
(import x/sys/proc)
(import x/type/err)

(def %bad (fn (_ text) (error (Str8 append "bundle: " text))))

(def %join (fn (_ dir name) (Str8 append dir "/" name)))

(def %say (fn (_ text) (Sys fd-write 1 text)))

; text's lines, without their newlines; a last line with none counts.
(def %lines
  (fn (_ text)
    (let go ((s text) (acc ()))
      (let ((i (Str8 index-of "\n" s)))
        (if (null? i)
          (List reverse (if (str=? s "") acc (pair s acc)))
          (go (Str8 sub (+ i 1) (- (Str8 length s) (+ i 1)) s)
              (pair (Str8 sub 0 i s) acc)))))))

; line with its colour sequences, ESC [ ... m, taken out.
(def %plain
  (fn (_ line)
    (let go ((s line) (acc ""))
      (let ((i (Str8 index-of "\x1b[" s)))
        (if (null? i) (Str8 append acc s)
          (let ((tail (Str8 sub (+ i 2) (- (Str8 length s) (+ i 2)) s)))
            (let ((m (Str8 index-of "m" tail)))
              (if (null? m) (Str8 append acc s)
                (go (Str8 sub (+ m 1) (- (Str8 length tail) (+ m 1)) tail)
                    (Str8 append acc (Str8 sub 0 i s)))))))))))

; names with each kept once, in the order first met.
(def %unique
  (fn (_ names)
    (let go ((l names) (acc ()))
      (match
        ((null? l) (List reverse acc))
        ((List any? (fn (_ n) (str=? n (first l))) acc) (go (rest l) acc))
        (#t (go (rest l) (pair (first l) acc)))))))

; a's names that b lacks.
(def %without
  (fn (_ a b)
    (List filter (fn (_ n) (not (List any? (fn (_ m) (str=? m n)) b))) a)))

; The number a totals line, "N tests, ...", starts with, or nil.
(def %total
  (fn (_ line)
    (let ((i (Str8 index-of " tests," line)))
      (if (null? i) ()
        (let ((digits (Str8 sub 0 i line)))
          (if (str=? digits "") ()
            (let go ((k 0) (n 0))
              (if (= k (Str8 length digits)) n
                (let ((d (Str8 index-of (Str8 sub k 1 digits) "0123456789")))
                  (if (null? d) () (go (+ k 1) (+ (* n 10) d))))))))))))

; The names a known-failures list holds: its lines, less the blank ones and
; the comments.
(def known-failures
  (fn (_ text)
    (%unique
      (List filter
        (fn (_ l) (if (str=? l "") #f (not (Str8 starts? "#" l))))
        (List map (fn (_ l) (Str8 trim l)) (%lines text))))))

; What a spec run's output says against the names known to fail:
; (TOTAL NEW FIXED). TOTAL is the last totals line's count, nil when the run
; printed none; NEW the tests that failed and are not known; FIXED the known
; ones that did not fail.
(def spec-verdict
  (fn (_ output known)
    (let ((lines (List map %plain (%lines output))))
      (let ((failed (%unique
                      (List flat-map
                        (fn (_ l) (if (Str8 starts? "FAIL: " l) (list (Str8 sub 6 (- (Str8 length l) 6) l)) ()))
                        lines)))
            (total (let go ((l lines) (last ()))
                     (if (null? l) last
                       (let ((n (%total (first l))))
                         (go (rest l) (if (null? n) last n)))))))
        (list total (%without failed known) (%without known failed))))))

; The x this runs under: the wrapper beside its install, else what X names,
; else x on the path.
(def %wrapper
  (fn (_)
    (let ((beside (guard (_ ()) (Str8 append %install-root "/../../bin/x"))))
      (match
        ((if (null? beside) #f (File exists? beside)) beside)
        ((null? (Sys getenv "X")) "x")
        ((str=? (Sys getenv "X") "") "x")
        (#t (Sys getenv "X"))))))

; What the wrapper answers to one of its questions, a line.
(def %ask
  (fn (_ x flag)
    (let ((r (Proc capture (list x flag))))
      (if (= (first r) 0) (Str8 trim (rest r))
        (%bad (Str8 append x " " flag " failed: is this an x?"))))))

; argv run with the environment pairs env set; its exit status.
(def %child
  (fn (_ env argv)
    (Proc run-with! (list (pair (lit env) env)) argv)))

; One named step: said, run, and its outcome said. Answers #t when it passed.
(def %step
  (fn (_ name work)
    (do
      (%say (Str8 append "check: " name "\n"))
      (let ((ok (work)))
        (do (%say (Str8 append "check: " name (if ok " ok\n" " FAILED\n")))
            ok)))))

; The harness the specs boot from, written by the kit's generator: the boot,
; the bundle's roots, and its tests/harness.x where it has one. Answers #t
; when it was written.
(def %harness!
  (fn (_ env kit)
    (= 0 (%child env (list "sh" (%join kit "gen-harness.sh"))))))

; The specs, through the platform's runner, their output shown as it comes
; and kept; then the verdict on it.
(def %specs
  (fn (_ dir env share engine)
    (let ((kept (%join dir "tests/lib/check.out"))
          (contract (%join dir "tests/contract/known-failures.txt")))
      (do
        (%child
          (List append
            (list (pair "X_BIN" engine)
                  (pair "LANG_LIB" (%join dir "tests/lib/harness.gen.x"))
                  (pair "SPEC_PATH" (%join dir "tests/specs"))
                  (pair "SPEC_RUNNER_DIR" (%join share "tests"))
                  (pair "SPEC_SEAM_COLLECT" "0")
                  (pair "SPEC_BATCH" "1"))
            env)
          (list "sh" "-c" "sh \"$0\" 2>&1 | tee \"$1\"" (%join share "tests/spec-runner.sh") kept))
        (let ((v (spec-verdict (File read-all kept)
                               (if (File exists? contract) (known-failures (File read-all contract)) ()))))
          (do
            (File unlink kept)
            (match
              ((null? (first v))
                (do (%say "check: the suite printed no totals line, so it did not run\n") #f))
              ((= (first v) 0)
                (do (%say "check: the suite ran no tests\n") #f))
              (#t
                (do
                  (List for-each (fn (_ n) (%say (Str8 append "check: failed and not recorded: " n "\n")))
                    (first (rest v)))
                  (List for-each (fn (_ n) (%say (Str8 append "check: recorded as failing, passes now: " n "\n")))
                    (first (rest (rest v))))
                  (if (null? (first (rest v))) (null? (first (rest (rest v)))) #f))))))))))

; Check the bundle in dir: one meaning a global name, the specs, the linter
; and the documentation's examples, every step run whatever the one before
; it said. Answers #t when all passed.
(def check!
  (fn (_ dir)
    (let ((x (%wrapper)))
      (let ((share (%ask x "--share-dir"))
            (engine (%ask x "--engine-path")))
        (let ((kit (%join share "tools/bundle-kit"))
              (env (list (pair "BUNDLE" dir) (pair "X" x))))
          (match
            ((not (File exists? (%join dir "bundle.xon"))) (%bad (Str8 append "no bundle.xon in " dir)))
            ((not (File exists? (%join kit "gen-harness.sh"))) (%bad (Str8 append "this x ships no bundle kit at " kit)))
            (#t
              (let ((names (%step "one meaning a global name"
                             (fn (_) (= 0 (%child env (list "sh" (%join kit "dup-defs.sh")))))))
                    (specs (%step "specs"
                             (fn (_) (if (%harness! env kit) (%specs dir env share engine) #f))))
                    (lint (%step "lint"
                            (fn (_) (= 0 (%child env (list "sh" (%join kit "lint.sh") "--strict"))))))
                    (docs (%step "documentation examples"
                            (fn (_) (= 0 (%child env (list "sh" (%join kit "doctest.sh"))))))))
                (if names (if specs (if lint docs #f) #f) #f)))))))))

(provide bundle/check check! spec-verdict known-failures)
