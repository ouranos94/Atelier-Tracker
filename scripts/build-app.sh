#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f Vendor/OpenMPT/lib/libopenmpt.a ]]; then
    ./scripts/build-openmpt.sh
fi
swift build --build-system native -c release --arch arm64
TRACKER_BIN_DIR=$(swift build --build-system native -c release --arch arm64 --show-bin-path)
TRACKER_DIST_DIR="${1:-$PWD/dist}"
mkdir -p "$TRACKER_DIST_DIR"
TRACKER_DIST_DIR=$(cd "$TRACKER_DIST_DIR" && pwd)
TRACKER_APP="$TRACKER_DIST_DIR/Atelier Tracker.app"
mkdir -p "$TRACKER_APP/Contents/MacOS" "$TRACKER_APP/Contents/Resources"
cp "$TRACKER_BIN_DIR/AtelierTracker" "$TRACKER_APP/Contents/MacOS/AtelierTracker"
cp THIRD_PARTY_NOTICES.md "$TRACKER_APP/Contents/Resources/"
mkdir -p "$TRACKER_APP/Contents/Resources/Licenses"
cp Vendor/OpenMPT/LICENSE "$TRACKER_APP/Contents/Resources/Licenses/OpenMPT-BSD.txt"
cp Vendor/OpenMPT/licenses/* "$TRACKER_APP/Contents/Resources/Licenses/"
/usr/libexec/PlistBuddy -c 'Clear dict' "$TRACKER_APP/Contents/Info.plist" 2>/dev/null || true
cat > "$TRACKER_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Atelier Tracker</string>
<key>CFBundleDisplayName</key><string>Atelier Tracker</string>
<key>CFBundleIdentifier</key><string>studio.atelier.tracker</string>
<key>CFBundleExecutable</key><string>AtelierTracker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.12.0</string>
<key>CFBundleVersion</key><string>19</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>Atelier Tracker — 2026</string>
</dict></plist>
PLIST
swift scripts/make-icon.swift "$TRACKER_DIST_DIR/AppIcon.iconset"
iconutil -c icns "$TRACKER_DIST_DIR/AppIcon.iconset" -o "$TRACKER_APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$TRACKER_APP"
print "Application prête : $TRACKER_APP"
