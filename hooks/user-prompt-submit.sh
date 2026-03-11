#!/bin/bash
set -euo pipefail

DATA_DIR="$HOME/.local/share/ghostty-notify"
NOTIF_FILE="$DATA_DIR/notifications.json"
LOCK_DIR="/tmp/ghostty-notify.lock"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

[ -z "$SESSION_ID" ] && exit 0
[ -f "$NOTIF_FILE" ] || exit 0

# Acquire lock
while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.05; done
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

NOTIFS=$(cat "$NOTIF_FILE")
NOTIFS=$(echo "$NOTIFS" | jq --arg sid "$SESSION_ID" '[.[] | select(.session_id != $sid)]')

TMP=$(mktemp /tmp/ghostty-notify.XXXXXX)
echo "$NOTIFS" > "$TMP"
mv "$TMP" "$NOTIF_FILE"
