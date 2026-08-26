#!/usr/bin/env bash
# Re-inject the Creality CR-200B profiles into a stock CrealityPrint AppImage.
#
# Creality dropped CR-200B support after Creality Print 4.3.8 and said they will
# not port it (github.com/CrealityOfficial/CrealityPrint/issues/424), so every
# upgrade ships without it and this has to be re-applied.
#
# Usage: ./reapply.sh <stock-CrealityPrint-*.AppImage> [output.AppImage]
set -euo pipefail

SRC=${1:?usage: reapply.sh <stock.AppImage> [out.AppImage]}
SRC=$(readlink -f "$SRC")
OUT=${2:-${SRC%.AppImage}-CR200B.AppImage}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

for t in mksquashfs unsquashfs python3; do
    command -v "$t" >/dev/null || { echo "missing: $t" >&2; exit 1; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> extracting $SRC"
OFFSET=$("$SRC" --appimage-offset)
unsquashfs -q -o "$OFFSET" -d "$WORK/AppDir" "$SRC" >/dev/null

echo "==> generating CR-200B profiles"
python3 "$HERE/make_cr200b.py" "$WORK/AppDir/resources/profiles"

COVER="$HERE/Creality CR-200B_cover.png"
[ -f "$COVER" ] || COVER="$HERE/../../resources/profiles/Creality/Creality CR-200B_cover.png"
[ -f "$COVER" ] && cp "$COVER" "$WORK/AppDir/resources/profiles/Creality/"

echo "==> repacking"
dd if="$SRC" of="$WORK/runtime" bs="$OFFSET" count=1 status=none
mksquashfs "$WORK/AppDir" "$WORK/fs.squashfs" \
    -root-owned -noappend -comp zstd -Xcompression-level 15 -b 131072 -no-progress >/dev/null
cat "$WORK/runtime" "$WORK/fs.squashfs" > "$OUT"
chmod +x "$OUT"

echo "==> wrote $OUT"
echo "    remember to point ~/.local/share/applications/crealityprint.desktop at it"
