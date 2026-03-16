import Foundation

public func relativeTime(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    guard let date = f.date(from: iso) else { return "" }
    let s = Int(-date.timeIntervalSinceNow)
    if s < 10 { return "just now" }
    if s < 60 { return "\(s)s ago" }
    if s < 3600 { return "\(s / 60)m ago" }
    if s < 86400 { return "\(s / 3600)h ago" }
    return "\(s / 86400)d ago"
}

public func isoTimestamp() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.string(from: Date())
}

public enum NotificationType: Sendable {
    case action
    case idle

    public init(message: String) {
        let m = message.lowercased()
        if m.contains("permission") || m.contains("question") {
            self = .action
        } else {
            self = .idle
        }
    }
}

public func readStdin() -> Data? {
    var data = Data()
    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buf.deallocate() }
    while true {
        let count = fread(buf, 1, 4096, stdin)
        if count == 0 { break }
        data.append(buf, count: count)
    }
    return data.isEmpty ? nil : data
}

public func parseHookInput(from data: Data) -> HookInput? {
    try? JSONDecoder().decode(HookInput.self, from: data)
}
