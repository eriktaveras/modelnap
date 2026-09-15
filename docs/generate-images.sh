#!/usr/bin/env bash
# Regenera las imágenes de docs/images a partir de la app compilada.
#   ./docs/generate-images.sh     (después de ./build.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ModelNap.app"
BIN="$APP/Contents/MacOS/ModelNap"
SHOTS="build/shots"
[[ -x "$BIN" ]] || ./build.sh
mkdir -p "$SHOTS"

echo "==> capturas del panel (modo demo)"
for mode in light dark; do
  "$BIN" --snapshot "$SHOTS/panel-$mode.png" "$mode" demo -AppleLanguages "(es)" >/dev/null
  "$BIN" --snapshot "$SHOTS/settings-$mode.png" "$mode" settings demo -AppleLanguages "(es)" >/dev/null
done
"$BIN" --snapshot "$SHOTS/panel-en-light.png" light demo -AppleLanguages "(en)" >/dev/null
"$BIN" --snapshot "$SHOTS/panel-en-dark.png" dark demo -AppleLanguages "(en)" >/dev/null
"$BIN" --snapshot "$SHOTS/settings-en-light.png" light settings demo -AppleLanguages "(en)" >/dev/null

echo "==> fondo del instalador"
swiftc -O -swift-version 5 -framework AppKit Sources/Logo.swift Tools/dmgbackground/main.swift -o build/dmgbackground
build/dmgbackground build/dmg-fondo "$(cat VERSION)" >/dev/null

echo "==> composición"
swiftc -O -swift-version 5 -framework AppKit Sources/Logo.swift Sources/Mark.swift Tools/readme-images/main.swift -o build/readme-images
build/readme-images "$SHOTS" docs/images build/dmg-fondo@2x.png "$APP"

echo "==> logo"
swiftc -O -swift-version 5 -framework AppKit Sources/Logo.swift Tools/logo/main.swift -o build/logo
build/logo docs/logo
