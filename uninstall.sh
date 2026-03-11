#!/bin/bash
set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/ghostty-notify"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.ghosttynotify.plist"

echo "Uninstalling GhosttyNotify..."

# Stop and remove LaunchAgent
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Kill running instance
pkill -f ghostty-notify 2>/dev/null || true

# Remove binary
rm -f "$BIN_DIR/ghostty-notify"

# Remove hook scripts
rm -f "$HOOKS_DIR/session-start.sh"
rm -f "$HOOKS_DIR/notification.sh"
rm -f "$HOOKS_DIR/user-prompt-submit.sh"

# Remove data
rm -rf "$DATA_DIR"

# Clean up lock
rmdir /tmp/ghostty-notify.lock 2>/dev/null || true

echo "Uninstalled."
echo "Remember to remove the hooks entries from ~/.claude/settings.json"
