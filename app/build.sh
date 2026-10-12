#!/bin/zsh
# Compila o "Disco Livre.app" (precisa só das Ferramentas de Linha de Comando: xcode-select --install)
set -e
cd "${0:A:h}"

APP="build/Disco Livre.app"
TMP="build/tmp"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$TMP/AppIcon.iconset"

if swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos13.0 \
    DiscoLivre.swift -o "$TMP/DiscoLivre-arm64" 2>/dev/null &&
   swiftc -O -swift-version 5 -parse-as-library -target x86_64-apple-macos13.0 \
    DiscoLivre.swift -o "$TMP/DiscoLivre-x86_64" 2>/dev/null &&
   lipo -create "$TMP/DiscoLivre-arm64" "$TMP/DiscoLivre-x86_64" -output "$APP/Contents/MacOS/DiscoLivre" &&
   swiftc -O -swift-version 5 icone.swift -o "$TMP/icone" &&
   "$TMP/icone" "$TMP/AppIcon.iconset" &&
   iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"; then
  print -r -- "Compilação SwiftUI concluída."
else
  print -r -- "SwiftUI indisponível neste toolchain; compilando a versão leve da barra de menus com AppKit."
  rm -rf "$APP" "$TMP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$TMP"
  TARGET_ARCH=$(uname -m)
  [[ $TARGET_ARCH == arm64 || $TARGET_ARCH == x86_64 ]] || { print -r -- "Arquitetura não suportada: $TARGET_ARCH" >&2; exit 1; }
  swiftc -O -swift-version 5 -target "$TARGET_ARCH-apple-macos13.0" \
    DiscoLivreFallback.swift -framework AppKit -o "$APP/Contents/MacOS/DiscoLivre"
  cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>DiscoLivre</string>
  <key>CFBundleIdentifier</key><string>com.disco-livre.app</string>
  <key>CFBundleName</key><string>Disco Livre</string>
  <key>CFBundleDisplayName</key><string>Disco Livre</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
  codesign --force --sign - "$APP"
  rm -rf "$TMP"
  print -r -- "✓ $APP (AppKit)"
  exit 0
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>DiscoLivre</string>
  <key>CFBundleIdentifier</key><string>com.disco-livre.app</string>
  <key>CFBundleName</key><string>Disco Livre</string>
  <key>CFBundleDisplayName</key><string>Disco Livre</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

codesign --force --sign - "$APP"
rm -rf "$TMP"
print -r -- "✓ $APP"
