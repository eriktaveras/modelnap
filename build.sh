#!/usr/bin/env bash
# Compila Interruptor Ollama (binario universal: Apple Silicon + Intel) y arma el bundle.
# Sin proyecto de Xcode: swiftc directo.
#   ./build.sh            -> construye en ./build
#   ./build.sh --install  -> además lo copia a ~/Applications y lo relanza
# Para el instalador .dmg que se comparte: ./package.sh
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/Interruptor Ollama.app"
VERSION="$(cat VERSION)"
MIN_OS="14.0"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> binario universal"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_OS" \
    -framework AppKit -framework SwiftUI -framework ServiceManagement \
    Sources/*.swift \
    -o "$BUILD/InterruptorOllama-$arch"
done
lipo -create "$BUILD/InterruptorOllama-arm64" "$BUILD/InterruptorOllama-x86_64" \
  -output "$APP/Contents/MacOS/InterruptorOllama"
rm "$BUILD"/InterruptorOllama-{arm64,x86_64}

echo "==> fuentes (OFL)"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"

echo "==> icono"
swiftc -O -swift-version 5 -framework AppKit \
  Sources/Mark.swift Tools/main.swift \
  -o "$BUILD/makeicon"
"$BUILD/makeicon" "$BUILD/AppIcon.iconset"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>InterruptorOllama</string>
  <key>CFBundleIdentifier</key><string>com.taverassolutions.interruptor-ollama</string>
  <key>CFBundleName</key><string>Interruptor Ollama</string>
  <key>CFBundleDisplayName</key><string>Interruptor Ollama</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>es</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Taveras Solutions LLC · No afiliado a Ollama</string>
  <!-- Vive en la barra de menús: sin icono en el Dock ni en el conmutador. -->
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Con DEVELOPER_ID (p. ej. "Developer ID Application: Taveras Solutions LLC (TEAMID)")
# se firma con runtime endurecido para poder notarizar; si no, firma ad-hoc.
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "==> firma Developer ID"
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
else
  echo "==> firma ad-hoc (solo pruebas locales; para compartir usa DEVELOPER_ID y NOTARY_PROFILE)"
  codesign --force --sign - "$APP"
fi

echo "==> listo: $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
  pkill -x InterruptorOllama 2>/dev/null || true
  rm -rf "$DEST/Interruptor Ollama.app"
  cp -R "$APP" "$DEST/"
  echo "==> instalado en $DEST/Interruptor Ollama.app"
  open "$DEST/Interruptor Ollama.app"
fi
