# getallnotofonts

A Bash script that downloads the Noto font families from Google's upstream GitHub repositories and copies them into a single directory.

## What it collects

| Source repository | What is copied |
| --- | --- |
| [notofonts/notofonts.github.io](https://github.com/notofonts/notofonts.github.io) | Static TrueType fonts from `fonts/<Family>/hinted/ttf/`. If a font has no hinted build, the script uses the one from `unhinted/ttf/`. |
| [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) | The Sans and Serif CJK font collections (`.ttc`) from `Sans/OTC/` and `Serif/OTC/` |
| [googlefonts/noto-emoji](https://github.com/googlefonts/noto-emoji) | `NotoColorEmoji.ttf` |

The script takes hinted fonts first and uses unhinted ones only where no hinted build exists, which is what Debian and Ubuntu package. Variable fonts and other builds are skipped because their file names would collide.

## Requirements

- Bash 4 or later
- Git 2.25 or later (for `sparse-checkout`, partial clones and `--no-cone`)
- GNU `find`, `cp`, `mktemp`
- A network connection. These repositories are large, so the script uses shallow, blobless, sparse clones and downloads only the paths it needs.

## Usage

```bash
./getallnotofonts.sh <dest>
./getallnotofonts.sh --system
```

`<dest>` must not exist yet; the script creates it. Example:

```bash
./getallnotofonts.sh ~/noto-fonts
```

Each repository is cloned into a temporary directory, its fonts are copied to `<dest>`, and the clone is deleted. The temporary directory is also removed if the script fails or is interrupted.

### Installing the fonts (optional)

To make the fonts available to your user on Linux:

```bash
./getallnotofonts.sh ~/.local/share/fonts/noto
fc-cache -f
```

To install them for all users, run the script as root with `--system` instead of a path:

```bash
sudo ./getallnotofonts.sh --system
sudo fc-cache -f
```

This puts the fonts in `/usr/local/share/fonts/notofonts`, which must not exist yet. `/usr/local/share/fonts` must already exist.

## License

The script is licensed under the [GNU General Public License v3.0 or later](LICENSE).

The Noto fonts are licensed under the [SIL Open Font License 1.1](https://openfontlicense.org/). This repository contains only the download script, not the fonts.
