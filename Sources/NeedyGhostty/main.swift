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
          needyghostty hook stop                 Handle Stop hook (reads stdin)
          needyghostty hook user-prompt-submit   Handle UserPromptSubmit hook (reads stdin)
          needyghostty --help                    Show this help
          needyghostty --version                 Show version

        Hook configuration for ~/.claude/settings.json:
          {
            "hooks": {
              "SessionStart": [{"hooks": [{"type": "command", "command": "needyghostty hook session-start"}]}],
              "Stop": [{"hooks": [{"type": "command", "command": "needyghostty hook stop"}]}],
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
    let subcommand = args.count > 1 ? args[1] : "<none>"

    guard let stdinData = readStdin() else {
        exit(0)
    }

    guard let input = parseHookInput(from: stdinData) else {
        exit(1)
    }

    let handler = HookHandler(dataDir: dataDir)

    switch subcommand {
    case "session-start":
        handler.handleSessionStart(input: input)
    case "notification", "stop":
        handler.handleNotification(input: input)
    case "user-prompt-submit":
        handler.handleUserPromptSubmit(input: input)
    default:
        switch input.hook_event_name {
        case "SessionStart":
            handler.handleSessionStart(input: input)
        case "Notification":
            handler.handleNotification(input: input)
        case "Stop":
            handler.handleNotification(input: input)
        case "UserPromptSubmit":
            handler.handleUserPromptSubmit(input: input)
        default:
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
