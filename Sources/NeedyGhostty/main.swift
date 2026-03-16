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

let logFile = dataDir + "/hook.log"

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(msg)\n"
    if let fh = FileHandle(forWritingAtPath: logFile) {
        fh.seekToEndOfFile()
        fh.write(Data(line.utf8))
        fh.closeFile()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: Data(line.utf8))
    }
}

if args.first == "hook" {
    let subcommand = args.count > 1 ? args[1] : "<none>"
    log("hook \(subcommand) invoked")

    guard let stdinData = readStdin() else {
        log("hook \(subcommand): no stdin data")
        exit(0)
    }
    log("hook \(subcommand): stdin=\(String(data: stdinData, encoding: .utf8) ?? "<binary>")")

    guard let input = parseHookInput(from: stdinData) else {
        log("hook \(subcommand): failed to parse JSON")
        exit(1)
    }
    log("hook \(subcommand): session_id=\(input.session_id ?? "<nil>") message=\(input.message ?? "<nil>")")

    let handler = HookHandler(dataDir: dataDir)

    switch subcommand {
    case "session-start":
        handler.handleSessionStart(input: input)
        log("hook session-start: done")
    case "notification", "stop":
        handler.handleNotification(input: input)
        log("hook \(subcommand): done")
    case "user-prompt-submit":
        handler.handleUserPromptSubmit(input: input)
        log("hook user-prompt-submit: done")
    default:
        switch input.hook_event_name {
        case "SessionStart":
            handler.handleSessionStart(input: input)
        case "Notification":
            handler.handleNotification(input: input)
        case "UserPromptSubmit":
            handler.handleUserPromptSubmit(input: input)
        default:
            log("hook: unknown type '\(subcommand)' / event '\(input.hook_event_name ?? "<nil>")'")
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
