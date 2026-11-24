# x-bundle

![Bitwise, the x owl, wearing a number sign](docs/bitwise-banner.svg)

The bundle tool for [x-lang](https://github.com/jonruttan/x-lang), and the
index of official bundles.

    x -l bundle -- COMMAND [ARG] [OPTIONS]

## Commands

    install WHAT  Install a bundle and every bundle it requires. WHAT is a
                  name in the index, OWNER/REPO, or the URL of a bundle.pin.xon
    list          List the installed bundles and their versions
    remove NAME   Remove an installed bundle

    -d, --dir DIR  The bundles directory, in place of the one this x reads
    -V, --version  Print the version and exit
    -h, --help     Print this help and exit

```sh
x -l bundle -- install gfx                  # a name the index lists
x -l bundle -- install alice/x-foo          # a repository on github.com
x -l bundle -- install https://example.org/foo/bundle.pin.xon
x -l bundle -- list
x -l bundle -- remove gfx
```

## What install does

A release of a bundle publishes three files: a tarball, its SHA-256, and a
`bundle.pin.xon` naming both. Install finds the pin, and the platform's pin
tool does the rest: the tarball is held to the pin's digest before it is
unpacked, and it replaces an earlier install only once it is whole.

- **A name** is looked up in the index, which gives its repository.
- **`OWNER/REPO`** is a repository on github.com, with or without an index
  row. Its latest release's pin is read.
- **A URL** is the pin itself, on any host.

Each `(requires-bundle "NAME" "VERSION" "OWNER/REPO")` row of the installed
bundle's `bundle.xon` is then installed the same way: that release of that
repository, the latest when the row names no version. A row that names no
repository takes the one the index lists under its name, and
`jonruttan/x-NAME` when the index has no such row. A requirement already
installed at the release asked for is left alone.

Two environment variables move where install looks. `X_BUNDLE_INDEX` names
another index, as a URL or a `file://` path. `X_BUNDLE_HOST` replaces
`https://github.com` under an `OWNER/REPO` reference.

## The index

[`index.xon`](index.xon) lists the official bundles, one row each, sorted by
name:

```x
(bundle "gfx" "jonruttan/x-lib-gfx")
```

A name is bare. A reference is `OWNER/REPO` on github.com, or
`DOMAIN/OWNER/REPO`. The index holds no versions, so a new release of a
bundle changes nothing here.

To add a bundle, open a pull request adding its row. The bundle needs a
release that publishes a `bundle.pin.xon`. A bundle needs no row to be
installed by its reference or its pin's URL: the index is the list of bare
names, not a gate.

## Tests

```sh
sh tests/spec-runner.sh
```

The suite installs from fixture releases under `tests/fixtures`, laid out
under a directory as github.com lays out releases, and reaches no network.
