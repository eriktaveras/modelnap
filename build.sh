#!/usr/bin/env bash
# Compila ModelNap (binario universal: Apple Silicon + Intel) y arma el bundle.
# Sin proyecto de Xcode: swiftc directo.
#   ./build.sh            -> construye en ./build
#   ./build.sh --install  -> además lo copia a ~/Applications y lo relanza
#   ./build.sh --test     -> solo el banco de pruebas de IdleTracker
# Para el instalador .dmg que se comparte: ./package.sh
set -euo pipefail

cd "$(dirname "$0")"

if [[ "${1:-}" == "--test" ]]; then
  mkdir -p build
  swiftc -swift-version 5 Sources/Activity.swift Sources/Ollama.swift Sources/SystemMemory.swift Sources/L10n.swift Tests/main.swift \
    -o build/idle-tests 2>&1 | grep -v "^$" || true
  exec ./build/idle-tests
fi
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/ModelNap.app"
VERSION="$(cat VERSION)"
MIN_OS="14.0"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> binario universal"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_OS" \
    -framework AppKit -framework SwiftUI -framework ServiceManagement \
    Sources/*.swift \
    -o "$BUILD/ModelNap-$arch"
done
lipo -create "$BUILD/ModelNap-arm64" "$BUILD/ModelNap-x86_64" \
  -output "$APP/Contents/MacOS/ModelNap"
rm "$BUILD"/ModelNap-{arm64,x86_64}

echo "==> traducciones"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

echo "==> icono"
swiftc -O -swift-version 5 -framework AppKit \
  Sources/Logo.swift Sources/Mark.swift Tools/main.swift \
  -o "$BUILD/makeicon"
"$BUILD/makeicon" "$BUILD/AppIcon.iconset"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ModelNap</string>
  <key>CFBundleIdentifier</key><string>com.taverassolutions.modelnap</string>
  <key>CFBundleName</key><string>ModelNap</string>
  <key>CFBundleDisplayName</key><string>ModelNap</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>es</string>
  <key>CFBundleLocalizations</key><array><string>es</string><string>en</string></array>
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
  pkill -x ModelNap 2>/dev/null || true
  rm -rf "$DEST/ModelNap.app"
  cp -R "$APP" "$DEST/"
  echo "==> instalado en $DEST/ModelNap.app"
  open "$DEST/ModelNap.app"
fi
