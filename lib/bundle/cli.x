; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/cli.x -- the command line
;
; @description `x bundle COMMAND [ARG] [OPTIONS]`: the options, declared once
;   to Opts, and the commands.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(module bundle/cli)

(import bundle/check check!)
(import x/sys/opts)
(import x/sys/posix)
(import x/type/err)
(import bundle/install bundles-dir install! installed remove!)
(import bundle/new new! running-release)
(import bundle/release release!)

(def bundle-version "0.1.0")

(def bundle-options
  (Opts declare "x bundle" "COMMAND [ARG] [OPTIONS]"
    "Start, check, release, install, list and remove x bundles."
    (list (Opts text "Commands:")
          (Opts text "  new NAME      Start a bundle in the directory NAME: its bundle.xon, one")
          (Opts text "                module, one spec and a README")
          (Opts text "  install WHAT  Install a bundle and every bundle it requires. WHAT is a")
          (Opts text "                name in the index, OWNER/REPO, the URL of a bundle.pin.xon,")
          (Opts text "                or a directory holding a bundle, such as .")
          (Opts text "  list          List the installed bundles and their versions")
          (Opts text "  remove NAME   Remove an installed bundle")
          (Opts text "  check         Check the bundle in this directory: its specs, the linter,")
          (Opts text "                its documentation's examples, one meaning a global name")
          (Opts text "  release TAG   Write the bundle in this directory into dist/ as release TAG:")
          (Opts text "                its tarball, the tarball's digest, and the bundle.pin.xon")
          (Opts text "                an install reads")
          (Opts text "")
          (Opts text "Options:")
          (Opts arg "-d" "--dir" "DIR" "The bundles directory, in place of the one this x reads")
          (Opts flag "--library" "With new: a library, a bundle with no entry")
          (Opts flag "-V" "--version" "Print the version and exit")
          (Opts flag "-h" "--help" "Print this help and exit"))
    (pair (lit help) #f)))

(def %say (fn (_ fd text) (Sys fd-write fd text)))

; A refusal: text and the usage on standard error, status 2.
(def %refuse
  (fn (_ text)
    (do (%say 2 (Str8 append "bundle: " text "\n" (Opts usage bundle-options))) 2)))

; work's status: 0 when it returns, 1 with the error's text on standard error
; when it raises.
(def %run
  (fn (_ work)
    (guard (e (do (%say 2 (Str8 append (Err text e) "\n")) 1))
      (do (work) 0))))

(def %list
  (fn (_ dir)
    (List for-each
      (fn (_ b) (%say 1 (Str8 append (first b) " " (if (null? (rest b)) "-" (rest b)) "\n")))
      (installed dir))))

; A bundle called name started under the directory this runs in, declaring
; the release of this x. An x with no release stamp leaves the row out, and
; says so, since the shared CI reads it.
(def %new
  (fn (_ name library?)
    (let ((release (running-release)))
      (do
        (%say 1 (Str8 append "bundle: started " (new! name library? "." release) "\n"))
        (if (null? release)
          (%say 2 "bundle: this x carries no release stamp: add (requires-release \"VERSION\") to bundle.xon\n")
          ())))))

(def bundle-main
  (fn (_ args)
    (def o (Opts parse bundle-options args))
    (def words (Opts operands o))
    (def command (if (null? words) "" (first words)))
    (def operands (if (null? words) () (rest words)))
    (def dir (fn (_) (bundles-dir (Opts value o "-d"))))
    (match
      ((not (null? (Opts unknown o))) (%refuse (Str8 append "no such option: " (Opts unknown o))))
      ((Opts on? o "-h") (do (%say 1 (Opts usage bundle-options)) 0))
      ((Opts on? o "-V") (do (%say 1 (Str8 append "x-bundle " bundle-version "\n")) 0))
      ((null? words) (%refuse "no command"))
      ((str=? command "new")
        (if (= (List length operands) 1)
          (%run (fn (_) (%new (first operands) (Opts on? o "--library"))))
          (%refuse "new takes one bundle's name")))
      ((str=? command "install")
        (if (= (List length operands) 1)
          (%run (fn (_) (install! (first operands) (dir))))
          (%refuse "install takes one bundle: a name, OWNER/REPO, a bundle.pin.xon URL, or a directory")))
      ((str=? command "list")
        (if (null? operands) (%run (fn (_) (%list (dir)))) (%refuse "list takes no operands")))
      ((str=? command "remove")
        (if (= (List length operands) 1)
          (%run (fn (_) (%say 1 (Str8 append "bundle: removed " (remove! (first operands) (dir)) "\n"))))
          (%refuse "remove takes one bundle's name")))
      ((str=? command "check")
        (if (null? operands)
          (guard (e (do (%say 2 (Str8 append (Err text e) "\n")) 1))
            (if (check! (Sys getcwd)) 0 1))
          (%refuse "check takes no operands")))
      ((str=? command "release")
        (if (= (List length operands) 1)
          (%run (fn (_)
                  (List for-each (fn (_ p) (%say 1 (Str8 append "bundle: wrote " p "\n")))
                    (release! (Sys getcwd) (first operands) (Str8 append (Sys getcwd) "/dist")))))
          (%refuse "release takes one tag")))
      (#t (%refuse (Str8 append "no such command: " command))))))

(provide bundle/cli bundle-main bundle-options bundle-version)
