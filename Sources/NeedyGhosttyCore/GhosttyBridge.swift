import Foundation

public struct GhosttyBridge {
    public init() {}

    public func getFocusedTerminalInfo() -> (id: String, name: String, workingDir: String)? {
        let script = """
            tell application "Ghostty"
              set t to focused terminal of selected tab of front window
              return (id of t) & linefeed & (name of t) & linefeed & (working directory of t)
            end tell
            """
        guard let output = runOsascriptSync(script) else { return nil }
        let lines = output.components(separatedBy: "\n")
        guard lines.count >= 3 else { return nil }

        let id = lines[0].trimmingCharacters(in: .whitespaces)
        let name = lines[1].trimmingCharacters(in: .whitespaces)
        let dir = lines[2].trimmingCharacters(in: .whitespaces)

        guard !id.isEmpty else { return nil }
        return (id, name, dir)
    }

    public func getFocusedTerminalId() -> String? {
        let script = """
            tell application "Ghostty"
                return id of focused terminal of selected tab of front window
            end tell
            """
        return runOsascriptSync(script)
    }

    public func focusTerminal(_ terminalId: String) {
        let escaped = terminalId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
            tell application "Ghostty"
                activate
                focus (first terminal whose id is "\(escaped)")
            end tell
            """
        runOsascriptAsync(script)
    }

    public func sendNotification(title: String, message: String) {
        let t = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let m = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        runOsascriptAsync("display notification \"\(m)\" with title \"\(t)\"")
    }

    private func runOsascriptSync(_ script: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runOsascriptAsync(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
        }
    }
}
