; # x-bundle -- the bundle tool and index on x-lang
;
; ## lib/bundle/run.x -- the entry
;
; @description `x -l bundle -- COMMAND [ARG] [OPTIONS]`.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The module bundle/run. x.sh boots the dialect bundle.xon declares, arms the
; bundle's lib/ with import-path!, imports this module and then calls its
; main.
(module bundle/run)
(import bundle/cli bundle-main)

(set! %lang-name "bundle")

; The operands: what follows the "--" after the launcher's own options.
; x-os's launcher passes the engine's own flags ahead of them, with no "--"
; between; they are left out.
(def %engine-flag?
  (fn (_ a) (List any? (fn (_ f) (str=? a f)) (list "--batch" "--quiet" "--no-color"))))
(def %operands
  (fn (self l) (if (if (null? l) #f (%engine-flag? (first l))) (self (rest l)) l)))

(def main
  (fn (_)
    (Sys exit (bundle-main (%operands (rest (Sys args (lit program))))))))

(provide bundle/run main)
