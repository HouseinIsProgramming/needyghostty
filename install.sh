#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="$HOME/.local/share/needyghostty"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.needyghostty.plist"

echo "Installing NeedyGhostty..."

# Check for Swift toolchain
if ! command -v swift &>/dev/null; then
    echo "Error: swift is required. Install Xcode command line tools."
    exit 1
fi

# Create directories
mkdir -p "$BIN_DIR" "$DATA_DIR" "$LAUNCH_AGENTS_DIR"

# Build
echo "  Building..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1 | tail -1

# Install binary
echo "  Installing binary..."
cp .build/release/needyghostty "$BIN_DIR/needyghostty"

# Install LaunchAgent
echo "  Installing LaunchAgent..."
sed "s|{{HOME}}|$HOME|g; s|{{BIN_DIR}}|$BIN_DIR|g" "$SCRIPT_DIR/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
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
cat <<'HOOKS'
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "needyghostty hook session-start"}]}],
    "Notification": [{"hooks": [{"type": "command", "command": "needyghostty hook notification"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "needyghostty hook user-prompt-submit"}]}]
  }
HOOKS
echo ""
echo "Make sure $BIN_DIR is in your PATH."
