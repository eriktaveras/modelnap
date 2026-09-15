#!/usr/bin/env bash
# Arma el instalador para compartir: dist/ModelNap-<version>.dmg
# (ventana con fondo de marca, la app y un acceso a Aplicaciones para arrastrar).
#
# Notarización opcional, cuando haya cuenta de Apple Developer:
#   xcrun notarytool store-credentials taveras --apple-id … --team-id … --password …
#   DEVELOPER_ID="Developer ID Application: … (TEAMID)" NOTARY_PROFILE=taveras ./package.sh
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"
VERSION="$(cat VERSION)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
APP="$BUILD/ModelNap.app"
DMG="$DIST/ModelNap-$VERSION.dmg"

./build.sh

# La app se notariza y grapa antes de meterla en el dmg: así lleva su propio
# ticket y abre sin conexión aunque alguien la copie fuera del dmg.
if [[ -n "${DEVELOPER_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> notarizando la app"
  ditto -c -k --keepParent "$APP" "$BUILD/app-notarizar.zip"
  xcrun notarytool submit "$BUILD/app-notarizar.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm "$BUILD/app-notarizar.zip"
fi

echo "==> fondo del instalador"
swiftc -O -swift-version 5 -framework AppKit Sources/Logo.swift Tools/dmgbackground/main.swift -o "$BUILD/dmgbackground"
"$BUILD/dmgbackground" "$BUILD/dmg-fondo" "$VERSION"
# TIFF con las dos resoluciones: Finder elige la @2x en pantallas Retina.
tiffutil -cathidpicheck "$BUILD/dmg-fondo.png" "$BUILD/dmg-fondo@2x.png" -out "$BUILD/dmg-fondo.tiff" >/dev/null

echo "==> dmg"
mkdir -p "$DIST"
rm -f "$DMG"
uvx --quiet --from dmgbuild dmgbuild \
  -s packaging/dmg-settings.py \
  -D app="$APP" \
  -D background="$BUILD/dmg-fondo.tiff" \
  -D icon="$APP/Contents/Resources/AppIcon.icns" \
  "ModelNap" "$DMG"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> notarizando el dmg"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl -a -t open --context context:primary-signature -vv "$DMG"
  fi
fi

(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256")
echo "==> listo: $DMG ($(du -h "$DMG" | cut -f1))"
