#!/bin/bash
set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="$HOME/.local/share/needyghostty"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.needyghostty.plist"

echo "Uninstalling NeedyGhostty..."

# Stop and remove LaunchAgent
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Kill running instance
pkill -x needyghostty 2>/dev/null || true

# Remove binary
rm -f "$BIN_DIR/needyghostty"

# Remove data
rm -rf "$DATA_DIR"

# Clean up lock
rmdir /tmp/needyghostty.lock 2>/dev/null || true

echo "Uninstalled."
echo "Remember to remove the hooks entries from ~/.claude/settings.json"
