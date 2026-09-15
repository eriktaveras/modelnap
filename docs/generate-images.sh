#!/usr/bin/env bash
# Regenera las imágenes de docs/images a partir de la app compilada.
#   ./docs/generate-images.sh     (después de ./build.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Interruptor Ollama.app"
BIN="$APP/Contents/MacOS/InterruptorOllama"
SHOTS="build/shots"
[[ -x "$BIN" ]] || ./build.sh
mkdir -p "$SHOTS"

echo "==> capturas del panel (modo demo)"
for mode in light dark; do
  "$BIN" --snapshot "$SHOTS/panel-$mode.png" "$mode" demo -AppleLanguages "(es)" >/dev/null
  "$BIN" --snapshot "$SHOTS/settings-$mode.png" "$mode" settings demo -AppleLanguages "(es)" >/dev/null
done
"$BIN" --snapshot "$SHOTS/panel-en-light.png" light demo -AppleLanguages "(en)" >/dev/null

echo "==> fondo del instalador"
swiftc -O -swift-version 5 -framework AppKit Tools/dmgbackground.swift -o build/dmgbackground
build/dmgbackground build/dmg-fondo "$(cat VERSION)" >/dev/null

echo "==> composición"
swiftc -O -swift-version 5 -framework AppKit Sources/Mark.swift Tools/readme-images/main.swift -o build/readme-images
build/readme-images "$SHOTS" docs/images build/dmg-fondo@2x.png "$APP"
