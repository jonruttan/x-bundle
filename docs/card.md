# bundle card

## Run

```sh
x -l bundle -- new NAME                   # start a bundle in ./NAME
x -l bundle -- install WHAT               # install it and what it requires
x -l bundle -- list                       # the installed bundles
x -l bundle -- remove NAME                # remove one
x -l bundle -- check                      # check the bundle in this directory
x -l bundle -- -V -> x-bundle 0.1.0
x -l bundle -- -h | sed 1q -> Usage: x bundle COMMAND [ARG] [OPTIONS]
x -l bundle -- frob 2>&1 | grep '^bundle:' -> bundle: no such command: frob
x -l bundle -- list extra 2>&1 | grep ^bundle: -> bundle: list takes no operands
x -l bundle -- 2>&1 | grep '^bundle:' -> bundle: no command
x -l bundle -- frob 2>/dev/null; echo $? -> 2
```

| Option                 | Is                                               |
|------------------------|--------------------------------------------------|
| `-d DIR` `--dir DIR`   | the bundles directory, not the one this x reads  |
| `--library`            | with `new`: a library, a bundle with no entry    |
| `-V` `--version`       | print the version and exit                       |
| `-h` `--help`          | print the help and exit                          |

| Status                 | Is                                               |
|------------------------|--------------------------------------------------|
| `0`                    | done                                             |
| `1`                    | it failed: the reason on standard error          |
| `2`                    | no command, no such command or option, or the    |
|                        | wrong count of operands                          |

## New

### an application

```bundle
bundle new demo
find demo -type f | LC_ALL=C sort
```

```output
bundle: started ./demo
demo/README.md
demo/bundle.xon
demo/lib/demo/run.x
demo/tests/specs/demo.spec.md
```

### a library

```bundle
bundle new --library kit
find kit -type f | LC_ALL=C sort
```

```output
bundle: started ./kit
kit/README.md
kit/bundle.xon
kit/lib/kit/kit.x
kit/tests/specs/kit.spec.md
```

| `new` writes           | Is                                               |
|------------------------|--------------------------------------------------|
| `bundle.xon`           | its name, `(dialect he)`, the release of this x  |
| `lib/NAME/run.x`       | the entry: a main that prints and exits          |
| `lib/NAME/NAME.x`      | with `--library`, the module, and no entry       |
| `tests/specs/NAME.spec.md` | one spec, of what the module says            |
| `README.md`            | how to install and run it                        |
| a name                 | lower-case letters, digits, hyphens; a letter    |
|                        | first                                            |

## Install, list, remove

```bundle
bundle new demo > /dev/null
bundle install ./demo -d b | cut -d' ' -f1-5
x -l demo
bundle list -d b
bundle remove demo -d b | cut -d' ' -f1-2
bundle list -d b
```

```output
bundle: installed demo from ./demo
hello from demo
demo -
bundle: removed
```

| `install WHAT`         | Is                                               |
|------------------------|--------------------------------------------------|
| `NAME`                 | a name in the index: `index.xon`                 |
| `OWNER/REPO`           | a repository on github.com: its latest release   |
| a URL                  | a `bundle.pin.xon`, on any host                  |
| `.` `./DIR` `/DIR`     | a directory holding a bundle; no version stamp   |
| `(requires-bundle ...)` | each installed the same way                     |
| `(payload "data" ...)` | more than `lib/` copied                          |
| `X_BUNDLE_INDEX`       | another index: a URL or a `file://` path         |
| `X_BUNDLE_HOST`        | in place of `https://github.com`                 |

| `list` prints          | Is                                               |
|------------------------|--------------------------------------------------|
| `NAME VERSION`         | an installed release                             |
| `NAME -`               | one with no version: from a directory            |

## Check

```bundle
bundle new demo > /dev/null
cd demo && bundle check | grep '^check: .* ok$'
```

```output
check: one meaning a global name ok
check: specs ok
check: lint ok
check: documentation examples ok
```

| Step                   | Holds                                            |
|------------------------|--------------------------------------------------|
| one meaning a global name | no two files define one global differently    |
| specs                  | `tests/specs/*.spec.md`, failures held to        |
|                        | `tests/contract/known-failures.txt`              |
| lint                   | the platform's linter, its structural rules      |
| documentation examples | each `(example "IN" "OUT")` in a `(doc ...)`     |

## More

| Where                  | What                                             |
|------------------------|--------------------------------------------------|
| `README.md`            | install's references and the index               |
| `index.xon`            | the official bundles, one row each               |
| `tests/fixtures/`      | the releases the suite installs from             |
