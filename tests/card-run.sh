#!/bin/sh
# tests/card-run.sh FILE -- run one bundle program from docs/card.md
#
# A program is shell lines.  `bundle` is `x -l bundle --`, found as the card
# check finds it; `x` is the x under test with the bundles directory `b`.
# The lines run in a directory of their own, removed after, that holds `b`,
# so every `-d b` in a program installs there and nowhere else.
x=${X:-x}
case $x in */*) x=$(cd "$(dirname "$x")" && pwd)/$(basename "$x") ;; esac
file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
d=$(mktemp -d) || exit 1
trap 'rm -rf "$d"' EXIT
mkdir "$d/b"
bundle() { "$x" -l bundle -- "$@" < /dev/null; }
x() { X_BUNDLE_DIR="$d/b" "$x" "$@" < /dev/null; }
cd "$d" || exit 1
. "$file"
