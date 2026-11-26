; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/new.x -- a new bundle's first files
;
; @description Writes the four files a bundle starts from: its declaration,
;   one module, one spec and a README.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; An application gets an entry, lib/NAME/run.x, and a library a module,
; lib/NAME/NAME.x. Either declares helium and the release of the x that
; made it, so its suite runs first against what its author has.
(module bundle/new)

(import x/sys/file)
(import x/type/err)

(def %bad (fn (_ text) (error (Str8 append "bundle: " text))))

(def %join (fn (_ dir name) (Str8 append dir "/" name)))

; Every byte of s is one of those in set, and s is not empty.
(def %all-in?
  (fn (_ set s)
    (if (str=? s "") #f
      (let go ((i 0))
        (match
          ((= i (Str8 length s)) #t)
          ((Str8 includes? (Str8 sub i 1 s) set) (go (+ i 1)))
          (#t #f))))))

; The index of the last mark in s before the index end, or nil.
(def %last-before
  (fn (_ mark s end)
    (let go ((i (- end (Str8 length mark))))
      (match
        ((< i 0) ())
        ((str=? (Str8 sub i (Str8 length mark) s) mark) i)
        (#t (go (- i 1)))))))

; The release a stamp names. An x built past a release is stamped as git
; describes it, TAG-COUNT-gHASH, and no such release can be fetched, so the
; tag is what a bundle declares; any other stamp is the release as written.
(def release-tag
  (fn (_ stamp)
    (let ((g (%last-before "-g" stamp (Str8 length stamp))))
      (if (null? g) stamp
        (let ((c (%last-before "-" stamp g)))
          (if (if (null? c) #f
                (if (%all-in? "0123456789abcdef" (Str8 sub (+ g 2) (- (Str8 length stamp) (+ g 2)) stamp))
                  (%all-in? "0123456789" (Str8 sub (+ c 1) (- g (+ c 1)) stamp))
                  #f))
            (Str8 sub 0 c stamp)
            stamp))))))

; The release of the x this runs on, as an install stamps it, or nil for an
; x that carries no stamp (a checkout).
(def running-release
  (fn (_)
    (guard (_ ())
      (release-tag (Str8 trim (File read-all (Str8 append %install-root "/contract/release")))))))

; A bundle's name: lower-case letters, digits and hyphens, a letter first.
(def %name?
  (fn (_ name)
    (if (%all-in? "abcdefghijklmnopqrstuvwxyz0123456789-" name)
      (%all-in? "abcdefghijklmnopqrstuvwxyz" (Str8 sub 0 1 name))
      #f)))

(def %declaration
  (fn (_ name library? release)
    (Str8 append
      "; bundle.xon -- what this bundle is.\n\n"
      "(name \"" name "\")\n\n"
      "(dialect he)\n\n"
      (if (null? release) "" (Str8 append "(requires-release \"" release "\")\n"))
      (if library? "" (if (null? release) "(entry run)\n" "\n(entry run)\n")))))

; The module: for a library NAME/NAME, for an application the entry
; NAME/run, whose main says the same thing and exits.
(def %module
  (fn (_ name library?)
    (if library?
      (Str8 append
        "; " name ".x -- " name "'s module.\n"
        "(module " name "/" name ")\n\n"
        "(def " name "-hello (fn (_) \"hello from " name "\"))\n\n"
        "(provide " name "/" name " " name "-hello)\n")
      (Str8 append
        "; run.x -- " name "'s entry: x imports this module and calls its main.\n"
        "(module " name "/run)\n\n"
        "(import x/sys/posix)\n\n"
        "(def " name "-hello (fn (_) \"hello from " name "\"))\n\n"
        "(def main\n"
        "  (fn (_)\n"
        "    (do (display (" name "-hello) \"\\n\")\n"
        "        (Sys exit 0))))\n\n"
        "(provide " name "/run main " name "-hello)\n"))))

(def %spec
  (fn (_ name library?)
    (Str8 append
      "# " name "\n\n"
      "## hello\n\n"
      "### it says where it is from\n\n"
      "```" name "\n"
      "(import " name "/" (if library? name "run") " " name "-hello)\n"
      "(write (" name "-hello))\n"
      "```\n"
      "---\n"
      "    \"hello from " name "\"\n")))

(def %readme
  (fn (_ name library?)
    (Str8 append
      "# " name "\n\n"
      (if library? "A library for" "An application on")
      " [x-lang](https://github.com/jonruttan/x-lang).\n\n"
      "```sh\n"
      "x bundle install .\n"
      (if library? "" (Str8 append "x " name "\n"))
      "```\n"
      (if library?
        (Str8 append "\n```x\n(import " name "/" name " " name "-hello)\n```\n")
        ""))))

; The four files of a new bundle called name, in the directory parent/name,
; which must not exist: bundle.xon, its module under lib/name, a spec under
; tests/specs and a README. release is what its (requires-release ...) row
; names, the row left out when it is nil. Answers the directory.
(def new!
  (fn (_ name library? parent release)
    (let ((dir (%join parent name)))
      (match
        ((not (%name? name))
          (%bad (Str8 append "not a bundle's name: " name
                  " (lower-case letters, digits and hyphens, a letter first)")))
        ((File exists? dir) (%bad (Str8 append dir " is already there")))
        (#t
          (do
            (File mkdir dir)
            (File mkdir (%join dir "lib"))
            (File mkdir (%join dir (Str8 append "lib/" name)))
            (File mkdir (%join dir "tests"))
            (File mkdir (%join dir "tests/specs"))
            (File write-all (%join dir "bundle.xon") (%declaration name library? release))
            (File write-all (%join dir (Str8 append "lib/" name "/" (if library? name "run") ".x"))
              (%module name library?))
            (File write-all (%join dir (Str8 append "tests/specs/" name ".spec.md")) (%spec name library?))
            (File write-all (%join dir "README.md") (%readme name library?))
            dir))))))

(provide bundle/new new! running-release release-tag)
