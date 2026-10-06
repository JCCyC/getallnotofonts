#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Juan Carlos Castro y Castro
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Collect Noto fonts (TrueType fonts / collections) from the upstream repos into one directory.
#
# Usage: getallnotofonts.sh <dest>
#        getallnotofonts.sh --system
#   <dest> must not already exist; it will be created.
#   --system installs into /usr/local/share/fonts/notofonts (must not exist;
#   /usr/local/share/fonts must exist). Requires root.

set -euo pipefail

system_fonts_dir=/usr/local/share/fonts

usage() {
    echo "Usage: $(basename "$0") <dest>" >&2
    echo "       $(basename "$0") --system" >&2
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

if [[ $1 == --system ]]; then
    if [[ $EUID -ne 0 ]]; then
        echo "Error: --system must be run as root" >&2
        exit 1
    fi
    if [[ ! -d "$system_fonts_dir" ]]; then
        echo "Error: '$system_fonts_dir' does not exist" >&2
        exit 1
    fi
    dest=$system_fonts_dir/notofonts
elif [[ $1 == -* ]]; then
    usage
else
    dest=$1
fi

if [[ -e "$dest" ]]; then
    echo "Error: '$dest' already exists" >&2
    exit 1
fi

mkdir -p "$dest"
dest=$(cd "$dest" && pwd)

tmpdir=""
cleanup() {
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -rf "$tmpdir"
    fi
}
trap cleanup EXIT

# clone_sparse <repo-url> [--no-cone] <path-or-pattern>...
# Shallow, blobless, sparse clone into a fresh temp dir (stored in $tmpdir),
# checking out only the given paths (or gitignore-style patterns with
# --no-cone). These repos are very large, so this avoids downloading everything.
clone_sparse() {
    local url=$1
    shift
    tmpdir=$(mktemp -d)
    echo "Cloning $url ..."
    git clone --quiet --depth 1 --filter=blob:none --sparse "$url" "$tmpdir"
    git -C "$tmpdir" sparse-checkout set "$@"
}

# copy_fonts <dir>...
# Copy every .ttf / .ttc file found under the given dirs into $dest.
copy_fonts() {
    local count
    count=$(find "$@" -type f \( -iname '*.ttf' -o -iname '*.ttc' \) -print \
        -exec cp -f {} "$dest/" \; | wc -l)
    echo "  copied $count file(s)"
}

remove_tmp() {
    rm -rf "$tmpdir"
    tmpdir=""
}

# copy_hinted_fonts <dir>
# Copy the static fonts under <dir>/<Family>/hinted/ttf/ into $dest, falling
# back to <dir>/<Family>/unhinted/ttf/ for any font with no hinted build.
# (Matches what Debian/Ubuntu package; other variants would collide by name.)
copy_hinted_fonts() {
    local dir=$1 f hinted=0 unhinted=0
    while IFS= read -r -d '' f; do
        cp -f "$f" "$dest/"
        hinted=$((hinted + 1))
    done < <(find "$dir" -type f -path '*/hinted/ttf/*' \( -iname '*.ttf' -o -iname '*.ttc' \) -print0)
    while IFS= read -r -d '' f; do
        if [[ ! -f "${f/\/unhinted\/ttf\//\/hinted\/ttf\/}" ]]; then
            cp -f "$f" "$dest/"
            unhinted=$((unhinted + 1))
        fi
    done < <(find "$dir" -type f -path '*/unhinted/ttf/*' \( -iname '*.ttf' -o -iname '*.ttc' \) -print0)
    echo "  copied $hinted hinted + $unhinted unhinted (fallback) file(s)"
}

# 1. notofonts.github.io: fonts/*/hinted/ttf/ (unhinted/ttf/ as fallback)
clone_sparse https://github.com/notofonts/notofonts.github.io/ \
    --no-cone '/fonts/*/hinted/ttf/' '/fonts/*/unhinted/ttf/'
copy_hinted_fonts "$tmpdir/fonts"
remove_tmp

# 2. noto-cjk: Sans/OTC/ and Serif/OTC/
clone_sparse https://github.com/notofonts/noto-cjk/ Sans/OTC Serif/OTC
copy_fonts "$tmpdir/Sans/OTC" "$tmpdir/Serif/OTC"
remove_tmp

# 3. noto-emoji: 2D/fonts/NotoColorEmoji.ttf
clone_sparse https://github.com/googlefonts/noto-emoji/ 2D/fonts
cp -f "$tmpdir/2D/fonts/NotoColorEmoji.ttf" "$dest/"
echo "  copied NotoColorEmoji.ttf"
remove_tmp

echo "Done. Fonts are in $dest"
