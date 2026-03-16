import Cocoa
import NeedyGhosttyCore

let dataDir: String = {
    let dir = NSHomeDirectory() + "/.local/share/needyghostty"
    try? FileManager.default.createDirectory(
        atPath: dir, withIntermediateDirectories: true)
    return dir
}()

func printUsage() {
    let usage = """
        NeedyGhostty - Menu bar notifications for Claude Code sessions in Ghostty

        Usage:
          needyghostty                          Start the menu bar app
          needyghostty hook session-start        Handle SessionStart hook (reads stdin)
          needyghostty hook notification         Handle Notification hook (reads stdin)
          needyghostty hook user-prompt-submit   Handle UserPromptSubmit hook (reads stdin)
          needyghostty hook <auto>               Auto-detect hook type from stdin JSON
          needyghostty --help                    Show this help
          needyghostty --version                 Show version

        Hook configuration for ~/.claude/settings.json:
          {
            "hooks": {
              "SessionStart": [{"hooks": [{"type": "command", "command": "needyghostty hook session-start"}]}],
              "Notification": [{"hooks": [{"type": "command", "command": "needyghostty hook notification"}]}],
              "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "needyghostty hook user-prompt-submit"}]}]
            }
          }
        """
    fputs(usage, stderr)
}

let args = Array(CommandLine.arguments.dropFirst())

if args.first == "--help" || args.first == "-h" {
    printUsage()
    exit(0)
}

if args.first == "--version" || args.first == "-v" {
    fputs("needyghostty 0.1.0\n", stderr)
    exit(0)
}

if args.first == "hook" {
    guard let stdinData = readStdin() else { exit(0) }
    guard let input = parseHookInput(from: stdinData) else { exit(1) }

    let handler = HookHandler(dataDir: dataDir)
    let subcommand = args.count > 1 ? args[1] : ""

    switch subcommand {
    case "session-start":
        handler.handleSessionStart(input: input)
    case "notification":
        handler.handleNotification(input: input)
    case "user-prompt-submit":
        handler.handleUserPromptSubmit(input: input)
    default:
        // Auto-detect from hook_event_name
        switch input.hook_event_name {
        case "SessionStart":
            handler.handleSessionStart(input: input)
        case "Notification":
            handler.handleNotification(input: input)
        case "UserPromptSubmit":
            handler.handleUserPromptSubmit(input: input)
        default:
            fputs("Unknown hook type. Use: session-start, notification, user-prompt-submit\n", stderr)
            exit(1)
        }
    }
    exit(0)
}

if !args.isEmpty {
    fputs("Unknown command: \(args.joined(separator: " "))\n", stderr)
    printUsage()
    exit(1)
}

// Start menu bar app
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
