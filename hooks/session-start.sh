#!/bin/bash
set -euo pipefail

DATA_DIR="$HOME/.local/share/ghostty-notify"
MAP_FILE="$DATA_DIR/session-map.json"
LOCK_DIR="/tmp/ghostty-notify.lock"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[ -z "$SESSION_ID" ] && exit 0

mkdir -p "$DATA_DIR"

# Get focused Ghostty terminal info
TERMINAL_INFO=$(osascript -e '
tell application "Ghostty"
  set t to focused terminal of selected tab of front window
  return {id of t, name of t, working directory of t}
end tell
' 2>/dev/null) || exit 0

TERMINAL_ID=$(echo "$TERMINAL_INFO" | cut -d',' -f1 | xargs)
TERMINAL_NAME=$(echo "$TERMINAL_INFO" | cut -d',' -f2 | xargs)
WORKING_DIR=$(echo "$TERMINAL_INFO" | cut -d',' -f3 | xargs)

[ -z "$TERMINAL_ID" ] && exit 0

# Acquire lock
while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.05; done
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

[ -f "$MAP_FILE" ] && MAP=$(cat "$MAP_FILE") || MAP='{}'

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MAP=$(echo "$MAP" | jq \
    --arg sid "$SESSION_ID" \
    --arg tid "$TERMINAL_ID" \
    --arg name "$TERMINAL_NAME" \
    --arg wdir "$WORKING_DIR" \
    --arg cwd "$CWD" \
    --arg ts "$TIMESTAMP" \
    '.[$sid] = {terminal_id: $tid, name: $name, working_dir: $wdir, cwd: $cwd, started_at: $ts}')

TMP=$(mktemp /tmp/ghostty-notify.XXXXXX)
echo "$MAP" > "$TMP"
mv "$TMP" "$MAP_FILE"
