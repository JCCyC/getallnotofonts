#!/usr/bin/env bash
# Collect Noto fonts (TrueType fonts / collections) from the upstream repos into one directory.
#
# Usage: getallnotofonts.sh <dest>
#   <dest> must not already exist; it will be created.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <dest>" >&2
    exit 1
fi

dest=$1

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
