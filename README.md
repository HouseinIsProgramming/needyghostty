# NeedyGhostty

Menu bar notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sessions running in [Ghostty](https://ghostty.org).

Get notified when Claude finishes responding — click the notification to jump straight to the right terminal.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Requirements

- **[Ghostty](https://ghostty.org) 1.3.0+** — requires the AppleScript API added in v1.3.0
- **macOS 13+**
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)**

## Features

- **Menu bar indicator** — shows how many sessions are waiting for input
- **Native macOS notifications** — banners with click-to-focus that jump to the correct Ghostty terminal
- **Auto-dismiss** — notifications clear automatically when you focus the terminal
- **Skip if focused** — won't notify you if you're already looking at the terminal

## Install

### From source

```bash
git clone https://github.com/HouseinIsProgramming/needyghostty.git
cd needyghostty
./install.sh
```

### From GitHub Releases

Download `NeedyGhostty.app.zip` from the [latest release](https://github.com/HouseinIsProgramming/needyghostty/releases/latest), unzip, and move to `~/Applications`.

Create a CLI symlink so hooks can find the binary:

```bash
mkdir -p ~/.local/bin
ln -sf ~/Applications/NeedyGhostty.app/Contents/MacOS/needyghostty ~/.local/bin/needyghostty
```

Make sure `~/.local/bin` is in your `PATH`.

## Setup

Add these hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "needyghostty hook session-start" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "needyghostty hook stop" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "needyghostty hook user-prompt-submit" }] }
    ]
  }
}
```

To start at login: **System Settings → General → Login Items → add NeedyGhostty**.

## How it works

NeedyGhostty uses Claude Code's [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks):

| Hook | What it does |
|---|---|
| `SessionStart` | Captures the Ghostty terminal ID for the session |
| `Stop` | Fires when Claude finishes responding — creates a notification |
| `UserPromptSubmit` | User started typing — clears the notification |

The menu bar app watches a local JSON file for changes and sends native macOS notifications. Clicking a notification uses Ghostty's AppleScript API to focus the correct terminal.

## Uninstall

```bash
./uninstall.sh
```

Or manually: quit the app, delete `~/Applications/NeedyGhostty.app`, remove `~/.local/bin/needyghostty` and `~/.local/share/needyghostty/`.

## License

MIT
