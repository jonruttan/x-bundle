; # x-bundle -- the bundle tool and index on x-lang
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The bundle kit's generator writes tests/lib/harness.gen.x: the dialect
; bundle.xon declares, the bundle's lib/ on the import path, then this file.
(import bundle/index index-rows index-read index-ref ref-parts ref-pin-url)
(import bundle/install bundles-dir install! installed remove!)
(import bundle/cli bundle-main)
(import bundle/new new! running-release release-tag)
;
; spec-host! lays the fixture tarballs out as github.com lays out releases,
; under a directory of this process, writes an index of them, and points
; X_BUNDLE_HOST and X_BUNDLE_INDEX there, so an install by name reaches no
; network. It answers an empty bundles directory.
(import x/sys/file)
(import x/sys/posix)
(import x/sys/bundle)
(import x/type/path)

(def spec-root (Str8 append "/tmp/x-bundle-spec." (Str8 str (Sys getpid))))

(def spec-mkdirs
  (fn (self dir)
    (if (File exists? dir) ()
      (do (self (Path dirname dir))
          (File mkdir dir)))))

; One release: a bundle.pin.xon at HOST/REPO/releases/WHERE naming the
; fixture FILE by its digest.
(def spec-publish
  (fn (_ repo where name release digest file)
    (let ((dir (Str8 append spec-root "/host/" repo "/releases/" where)))
      (do
        (spec-mkdirs dir)
        (File write-all (Str8 append dir "/bundle.pin.xon")
          (Str8 append "(name \"" name "\")\n(release \"" release "\")\n(bundle \"sha256:" digest
            "\" \"file://" (Bundle root "bundle") "/tests/fixtures/" file "\")\n"))))))

(def spec-index!
  (fn (_ text)
    (do (spec-mkdirs spec-root)
        (File write-all (Str8 append spec-root "/index.xon") text)
        (Sys setenv "X_BUNDLE_INDEX" (Str8 append "file://" spec-root "/index.xon")))))

; path and everything under it, where it exists.
(def spec-clear!
  (fn (self path)
    (match
      ((not (File exists? path)) ())
      ((eq? (File ltype path) (lit dir))
        (do (List for-each (fn (_ e) (self (Str8 append path "/" e))) (File list-dir path))
            (File rmdir path)))
      (#t (File unlink path)))))

(def spec-host!
  (fn (_)
    (do
      (spec-clear! (Str8 append spec-root "/bundles"))
      (spec-publish "alice/x-dep" "download/v2" "dep" "v2"
        "5d01832c32255a61ec03d7686714eefe3a6939c269e27f22c654f9d57bd68c89" "dep-v2.tar.gz")
      (spec-publish "alice/x-dep" "latest/download" "dep" "v3"
        "ca73540fed71dc5fb6f51d3d5c2366ebb8c2532cfb39ab4065c8831a3c864b58" "dep-v3.tar.gz")
      (spec-publish "jonruttan/x-app" "latest/download" "app" "v1"
        "f2ecf4c4aad0df01cca68ee276cf39a7d5062a9543f2e100cc3bdf55b8cc479c" "app-v1.tar.gz")
      (spec-publish "jonruttan/x-dep" "latest/download" "dep" "v2"
        "5d01832c32255a61ec03d7686714eefe3a6939c269e27f22c654f9d57bd68c89" "dep-v2.tar.gz")
      (spec-publish "jonruttan/x-use" "latest/download" "use" "v1"
        "d9891f171b76cc3bd1b935357e51dd98da2e28fa6be254d334007d3995796a85" "use-v1.tar.gz")
      (spec-index! "(bundle \"app\" \"jonruttan/x-app\")\n(bundle \"dep\" \"alice/x-dep\")\n")
      (Sys setenv "X_BUNDLE_HOST" (Str8 append "file://" spec-root "/host"))
      (Str8 append spec-root "/bundles"))))

; What raising work says, or "no raise".
(def spec-raise (fn (_ work) (guard (e (Err text e)) (do (work) "no raise"))))

; A bundle's checkout under this process's directory: a declaration that
; requires dep v2, one module, and two things a release leaves out, a
; version stamp and a suite. Answers the directory.
(def spec-source!
  (fn (_ name)
    (let ((src (Str8 append spec-root "/src/" name)))
      (do
        (spec-clear! src)
        (spec-mkdirs (Str8 append src "/lib/" name))
        (spec-mkdirs (Str8 append src "/tests"))
        (File write-all (Str8 append src "/bundle.xon")
          (Str8 append "(name \"" name "\")\n(dialect he)\n(requires-bundle \"dep\" \"v2\" \"alice/x-dep\")\n"))
        (File write-all (Str8 append src "/lib/" name "/m.x") "(module m)\n")
        (File write-all (Str8 append src "/tests/t.spec.md") "# t\n")
        (File write-all (Str8 append src "/version") "v9\n")
        src))))
