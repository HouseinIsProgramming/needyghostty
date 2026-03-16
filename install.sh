#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${APP_DIR:-$HOME/Applications}"
APP_BUNDLE="$APP_DIR/NeedyGhostty.app"
BIN_LINK="${BIN_DIR:-$HOME/.local/bin}/needyghostty"
DATA_DIR="$HOME/.local/share/needyghostty"

echo "Installing NeedyGhostty..."

# Check for Swift toolchain
if ! command -v swift &>/dev/null; then
    echo "Error: swift is required. Install Xcode command line tools."
    exit 1
fi

# Create directories
mkdir -p "$(dirname "$BIN_LINK")" "$DATA_DIR" "$APP_DIR"

# Build
echo "  Building..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1 | tail -1

# Create app bundle
echo "  Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp .build/release/needyghostty "$APP_BUNDLE/Contents/MacOS/needyghostty"
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.needyghostty</string>
    <key>CFBundleName</key>
    <string>NeedyGhostty</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>needyghostty</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Sign and register
echo "  Signing app bundle..."
codesign --force --deep -s - "$APP_BUNDLE"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE"

# Create CLI symlink
echo "  Creating CLI symlink..."
ln -sf "$APP_BUNDLE/Contents/MacOS/needyghostty" "$BIN_LINK"

# Create empty state files if needed
[ -f "$DATA_DIR/notifications.json" ] || echo '[]' > "$DATA_DIR/notifications.json"
[ -f "$DATA_DIR/session-map.json" ] || echo '{}' > "$DATA_DIR/session-map.json"

# Start the app
echo "  Starting NeedyGhostty..."
pkill -x needyghostty 2>/dev/null || true
sleep 1
open "$APP_BUNDLE"

echo ""
echo "Done! NeedyGhostty is running in your menu bar."
echo ""
echo "Add the following to your ~/.claude/settings.json:"
echo ""
cat <<HOOKS
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "$BIN_LINK hook session-start"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "$BIN_LINK hook stop"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "$BIN_LINK hook user-prompt-submit"}]}]
  }
HOOKS
echo ""
echo "Make sure $(dirname "$BIN_LINK") is in your PATH."
echo "To start at login: System Settings > General > Login Items > add NeedyGhostty"
