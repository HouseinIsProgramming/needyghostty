#!/bin/bash
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/Applications}"
BIN_LINK="${BIN_DIR:-$HOME/.local/bin}/needyghostty"
DATA_DIR="$HOME/.local/share/needyghostty"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.needyghostty.plist"

echo "Uninstalling NeedyGhostty..."

# Stop and remove LaunchAgent (legacy)
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Kill running instance
pkill -x needyghostty 2>/dev/null || true

# Remove app bundle and symlink
rm -f "$BIN_LINK"
rm -rf "$APP_DIR/NeedyGhostty.app"

# Remove data
rm -rf "$DATA_DIR"

# Clean up lock
rmdir /tmp/needyghostty.lock 2>/dev/null || true

echo "Uninstalled."
echo "Remember to remove the hooks entries from ~/.claude/settings.json"
