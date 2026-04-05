#!/bin/bash
# build.sh — Build MastodonWidget.app without Xcode
#
# Usage:
#   ./build.sh            → debug .app
#   ./build.sh release    → optimised .app
#   ./build.sh pkg        → optimised .app + .pkg installer   ← recommended
#   ./build.sh zip        → optimised .app + .zip archive
set -euo pipefail

SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
TARGET=arm64-apple-macosx26.0
APP=MastodonWidget
VERSION=1.0
BUNDLE=build/$APP.app
EXE=$BUNDLE/Contents/MacOS/$APP
SRC=MastodonWidget

# ── Mode ─────────────────────────────────────────────────────────────────────
MODE="${1:-debug}"
case "$MODE" in
  release) OPT_FLAGS=(-O -whole-module-optimization); echo "→ Release build" ;;
  pkg|zip)  OPT_FLAGS=(-O -whole-module-optimization); echo "→ Release build (for $MODE)" ;;
  *)        OPT_FLAGS=(-Onone -g);                     echo "→ Debug build" ;;
esac

# ── Bundle structure ─────────────────────────────────────────────────────────
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

# Expand Xcode build-variable placeholders in Info.plist
sed \
  -e "s/\$(EXECUTABLE_NAME)/$APP/g" \
  -e "s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g" \
  -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.mastodonwidget.app/g" \
  -e "s/\$(MARKETING_VERSION)/$VERSION/g" \
  -e "s/\$(CURRENT_PROJECT_VERSION)/1/g" \
  -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/26.0/g" \
  "$SRC/Info.plist" > "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

# ── Compile ──────────────────────────────────────────────────────────────────
echo "→ Compiling…"
swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  "${OPT_FLAGS[@]}" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation \
  -framework AuthenticationServices \
  -framework Security \
  -framework UniformTypeIdentifiers \
  "$SRC/Models/Models.swift" \
  "$SRC/Managers/AuthManager.swift" \
  "$SRC/Services/MastodonAPI.swift" \
  "$SRC/Services/StreamingService.swift" \
  "$SRC/Views/LiquidGlass.swift" \
  "$SRC/Views/LoginView.swift" \
  "$SRC/Views/StatusRowView.swift" \
  "$SRC/Views/ComposeView.swift" \
  "$SRC/Views/TimelineView.swift" \
  "$SRC/Views/ContentView.swift" \
  "$SRC/AppDelegate.swift" \
  "$SRC/MastodonWidgetApp.swift" \
  -o "$EXE"

# ── Ad-hoc sign ───────────────────────────────────────────────────────────────
echo "→ Signing (ad-hoc)…"
codesign -s - --force --deep "$BUNDLE"

echo "✓ Built:  $BUNDLE"

# ── Package ──────────────────────────────────────────────────────────────────
if [[ "$MODE" == "pkg" ]]; then
  PKG=build/$APP-$VERSION.pkg
  echo "→ Creating installer (.pkg)…"
  pkgbuild \
    --component "$BUNDLE" \
    --install-location /Applications \
    --identifier com.mastodonwidget.app \
    --version "$VERSION" \
    "$PKG"
  echo "✓ Installer: $PKG"
  echo ""
  echo "  Install: double-click $PKG"
  echo "           Installs MastodonWidget.app → /Applications automatically"

elif [[ "$MODE" == "zip" ]]; then
  ZIP=build/$APP-$VERSION.zip
  echo "→ Creating archive (.zip)…"
  rm -f "$ZIP"
  # ditto preserves extended attributes, resource forks, and app bundle structure
  ditto -c -k --keepParent "$BUNDLE" "$ZIP"
  echo "✓ Archive: $ZIP"
  echo ""
  echo "  Install: double-click $ZIP → drag MastodonWidget.app to /Applications"

else
  echo ""
  echo "  Run:     open $BUNDLE"
  echo "  Package: ./build.sh pkg    (creates a .pkg installer)"
  echo "  Archive: ./build.sh zip    (creates a .zip for drag-install)"
fi
