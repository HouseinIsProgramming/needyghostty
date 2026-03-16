#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
APP_DIR="$HOME/Applications"
DATA_DIR="$HOME/.local/share/needyghostty"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.needyghostty.plist"
APP_BUNDLE="$APP_DIR/NeedyGhostty.app"

echo "Installing NeedyGhostty..."

# Check for Swift toolchain
if ! command -v swift &>/dev/null; then
    echo "Error: swift is required. Install Xcode command line tools."
    exit 1
fi

# Create directories
mkdir -p "$BIN_DIR" "$DATA_DIR" "$LAUNCH_AGENTS_DIR" "$APP_DIR"

# Build
echo "  Building..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1 | tail -1

# Install CLI binary (for hooks)
echo "  Installing CLI binary..."
cp .build/release/needyghostty "$BIN_DIR/needyghostty"

# Create app bundle (for menu bar + native notifications)
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
    <key>CFBundleExecutable</key>
    <string>needyghostty</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign for notification permissions
echo "  Signing app bundle..."
codesign --force --deep -s - "$APP_BUNDLE"

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE"

# Install LaunchAgent
echo "  Installing LaunchAgent..."
sed "s|{{APP_DIR}}|$APP_DIR|g" "$SCRIPT_DIR/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Create empty state files if needed
[ -f "$DATA_DIR/notifications.json" ] || echo '[]' > "$DATA_DIR/notifications.json"
[ -f "$DATA_DIR/session-map.json" ] || echo '{}' > "$DATA_DIR/session-map.json"

echo ""
echo "Done! NeedyGhostty is running."
echo ""
echo "Add the following to your ~/.claude/settings.json:"
echo ""
cat <<HOOKS
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "$BIN_DIR/needyghostty hook session-start"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "$BIN_DIR/needyghostty hook stop"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "$BIN_DIR/needyghostty hook user-prompt-submit"}]}]
  }
HOOKS
echo ""
echo "Make sure $BIN_DIR is in your PATH."
