#!/usr/bin/env bash
# Install (or upgrade) the Kubuntu/Linux build of Creality Print from this
# fork's GitHub Releases into ~/Applications, with a menu entry and icon.
#
#   curl -fsSL https://raw.githubusercontent.com/hpflatorre/CrealityPrint/cr200b-kubuntu/scripts/repack/install.sh | bash
#
# Optional: INSTALL_DIR=... (default ~/Applications), VERSION=<tag> to pin.
set -euo pipefail
REPO=${REPO:-hpflatorre/CrealityPrint}
INSTALL_DIR=${INSTALL_DIR:-$HOME/Applications}
API="https://api.github.com/repos/$REPO/releases/${VERSION:+tags/}${VERSION:-latest}"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
if ! command -v fusermount3 >/dev/null && ! command -v fusermount >/dev/null; then
    echo "AppImages need FUSE: sudo apt install fuse3" >&2; exit 1
fi

echo "==> looking up $REPO release ${VERSION:-latest}"
JSON=$(curl -fsSL "$API")
URL=$(printf '%s' "$JSON" | grep -oE '"browser_download_url": *"[^"]+\.AppImage"' | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')
TAG=$(printf '%s' "$JSON" | grep -oE '"tag_name": *"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -n "$URL" ] || { echo "no AppImage asset found in release" >&2; exit 1; }
FILE=$(basename "$URL")

mkdir -p "$INSTALL_DIR" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/192x192/apps"
echo "==> downloading $FILE ($TAG)"
curl -fL --progress-bar -o "$INSTALL_DIR/$FILE.part" "$URL"
if curl -fsSL -o "$INSTALL_DIR/$FILE.sha256" "$URL.sha256" 2>/dev/null; then
    ( cd "$INSTALL_DIR" && sed "s| .*| $FILE.part|" "$FILE.sha256" | sha256sum -c --quiet - ) && echo "    checksum OK"
    rm -f "$INSTALL_DIR/$FILE.sha256"
fi
mv "$INSTALL_DIR/$FILE.part" "$INSTALL_DIR/$FILE"
chmod +x "$INSTALL_DIR/$FILE"
ln -sfn "$FILE" "$INSTALL_DIR/CrealityPrint.AppImage"      # stable path for the menu entry

echo "==> installing icon and menu entry"
"$INSTALL_DIR/$FILE" --appimage-extract CrealityPrint.png >/dev/null 2>&1 && \
    mv squashfs-root/CrealityPrint.png "$HOME/.local/share/icons/hicolor/192x192/apps/crealityprint.png" && rm -rf squashfs-root
cat > "$HOME/.local/share/applications/crealityprint.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=CrealityPrint
GenericName=3D Printing Slicer
Comment=Creality Print (Kubuntu/Linux build from $REPO, $TAG)
Exec=$INSTALL_DIR/CrealityPrint.AppImage %F
Icon=crealityprint
Terminal=false
Categories=Graphics;3DGraphics;Engineering;
Keywords=3D;printing;slicer;gcode;Creality;
MimeType=model/stl;model/3mf;application/vnd.ms-3mfdocument;application/prs.wavefront-obj;application/x-amf;
StartupWMClass=CrealityPrint
DESKTOP
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

# remove older versions of this fork's AppImage
find "$INSTALL_DIR" -maxdepth 1 \( -name 'CrealityPrint-V*-kubuntu.AppImage' -o -name 'CrealityPrint-V*-kubuntu.AppImage.sha256' \) ! -name "$FILE" -delete 2>/dev/null || true
echo "==> installed $TAG to $INSTALL_DIR/$FILE (menu: CrealityPrint)"
