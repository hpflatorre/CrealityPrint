#!/usr/bin/env bash
# Build the Kubuntu/Linux AppImage of this fork from Creality's stock release
# WITHOUT compiling: extract the official AppImage, inject the fork's
# resources (CR-200B profiles), regenerate AppRun and the .desktop entry from
# this repo's templates (src/platform/unix/*.sh.in), and repack.
#
# Usage: repack-appimage.sh <stock-CrealityPrint-*.AppImage> [output.AppImage]
# Needs: squashfs-tools, python3. Reuses the stock AppImage's own runtime, so
# no appimagetool is required.
set -euo pipefail

SRC=${1:?usage: repack-appimage.sh <stock.AppImage> [out.AppImage]}
SRC=$(readlink -f "$SRC")
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${2:-${SRC%.AppImage}-kubuntu.AppImage}
APP=CrealityPrint

for t in mksquashfs unsquashfs python3; do
    command -v "$t" >/dev/null || { echo "missing: $t" >&2; exit 1; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> extracting $SRC"
OFFSET=$("$SRC" --appimage-offset)
unsquashfs -q -o "$OFFSET" -d "$WORK/AppDir" "$SRC" >/dev/null

echo "==> injecting profiles"
python3 "$REPO/scripts/cr200b/make_cr200b.py" "$WORK/AppDir/resources/profiles"
cp "$REPO/resources/profiles/Creality/Creality CR-200B_cover.png" "$WORK/AppDir/resources/profiles/Creality/"

echo "==> regenerating AppRun from src/platform/unix/BuildLinuxImage.sh.in"
sed -n "/^cat << EOF >@SLIC3R_APP_CMD@/,/^EOF\$/p" "$REPO/src/platform/unix/BuildLinuxImage.sh.in" \
    | sed "s/@SLIC3R_APP_CMD@/$APP/g" > "$WORK/gen-apprun.sh"
( cd "$WORK" && bash gen-apprun.sh )
bash -n "$WORK/$APP"
install -m 755 "$WORK/$APP" "$WORK/AppDir/AppRun"

echo "==> regenerating $APP.desktop from src/platform/unix/build_appimage.sh.in"
sed -n "/^cat <<EOF > @SLIC3R_APP_NAME@.desktop/,/^EOF\$/p" "$REPO/src/platform/unix/build_appimage.sh.in" \
    | sed "s/@SLIC3R_APP_NAME@/$APP/g" > "$WORK/gen-desktop.sh"
( cd "$WORK" && bash gen-desktop.sh )
install -m 644 "$WORK/$APP.desktop" "$WORK/AppDir/$APP.desktop"

echo "==> repacking"
dd if="$SRC" of="$WORK/runtime" bs="$OFFSET" count=1 status=none
mksquashfs "$WORK/AppDir" "$WORK/fs.squashfs" \
    -root-owned -noappend -comp zstd -Xcompression-level 15 -b 131072 -no-progress >/dev/null
cat "$WORK/runtime" "$WORK/fs.squashfs" > "$OUT"
chmod +x "$OUT"
sha256sum "$OUT" > "$OUT.sha256"
echo "==> wrote $OUT"
