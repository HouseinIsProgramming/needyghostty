#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"
BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/ghostty-notify"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.ghosttynotify.plist"

echo "Installing GhosttyNotify..."

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: brew install jq"
    exit 1
fi

if ! command -v swiftc &>/dev/null; then
    echo "Error: swiftc is required. Install Xcode command line tools."
    exit 1
fi

# Create directories
mkdir -p "$HOOKS_DIR" "$BIN_DIR" "$DATA_DIR" "$LAUNCH_AGENTS_DIR"

# Copy hook scripts
echo "  Installing hook scripts..."
cp "$SCRIPT_DIR/hooks/session-start.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/notification.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/user-prompt-submit.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/session-start.sh" "$HOOKS_DIR/notification.sh" "$HOOKS_DIR/user-prompt-submit.sh"

# Compile Swift app
echo "  Compiling menu bar app..."
swiftc -framework Cocoa -O -o "$BIN_DIR/ghostty-notify" "$SCRIPT_DIR/app/main.swift"

# Generate LaunchAgent plist with real home path
echo "  Installing LaunchAgent..."
sed "s|{{HOME}}|$HOME|g" "$SCRIPT_DIR/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Unload if already loaded, then load
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Create empty state files if needed
[ -f "$DATA_DIR/notifications.json" ] || echo '[]' > "$DATA_DIR/notifications.json"
[ -f "$DATA_DIR/session-map.json" ] || echo '{}' > "$DATA_DIR/session-map.json"

echo ""
echo "Done! The menu bar app should now be running."
echo ""
echo "Add the following to your ~/.claude/settings.json (merge into existing hooks if any):"
echo ""
cat <<'HOOKS'
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]}],
    "Notification": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notification.sh"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/user-prompt-submit.sh"}]}]
  }
HOOKS
echo ""
echo "To test manually:"
echo "  echo '{\"session_id\":\"test\",\"cwd\":\"/tmp/demo\"}' | ~/.claude/hooks/session-start.sh"
echo "  echo '{\"session_id\":\"test\",\"message\":\"Needs permission\"}' | ~/.claude/hooks/notification.sh"
echo "  echo '{\"session_id\":\"test\"}' | ~/.claude/hooks/user-prompt-submit.sh"
