# CLAUDE.md

This file gives Claude Code guidance for working in this repository.

## Overview

The repository is one Bash script, `getallnotofonts.sh`. It sparse-clones three upstream Noto repositories and copies their `.ttf`/`.ttc` files into a destination directory, which it creates and which must not already exist. See `README.md` for what is collected from each repository.

## Structure of the script

- `set -euo pipefail`. Every step has to succeed.
- `clone_sparse <url> [--no-cone] <paths>...`: shallow (`--depth 1`), blobless (`--filter=blob:none`) sparse clone into a new `mktemp -d` directory, stored in the global `$tmpdir`. The upstream repos are very large, so keep using this pattern instead of full clones.
- `copy_fonts <dir>...`: copies every `.ttf`/`.ttc` file under the given dirs into `$dest`.
- `copy_hinted_fonts <dir>`: copies `*/hinted/ttf/*` files, then any `*/unhinted/ttf/*` file that has no hinted counterpart.
- `remove_tmp` deletes the clone after each source. An `EXIT` trap (`cleanup`) removes `$tmpdir` if the script fails.
- `$dest` is turned into an absolute path at the start.

## Conventions

- All fonts are copied flat into `$dest` with `cp -f`, so a file with the same name as an earlier one overwrites it. When adding a source, avoid file-name collisions; this is why only hinted/unhinted static TTFs are taken from notofonts.github.io.
- Quote all variables. Use `find -print0` with `read -d ''` for file lists.
- Errors go to stderr. Progress goes to stdout (`Cloning ...`, `copied N file(s)`).
- Keep the script dependent only on Bash, Git and coreutils/findutils.

## Testing

There is no test suite. Check changes with:

```bash
bash -n getallnotofonts.sh
shellcheck getallnotofonts.sh   # if installed
```

A full run (`./getallnotofonts.sh /some/new/dir`) downloads a lot of data and takes a while. Run it only when the change needs it, and point it at a directory outside the repo.
