import Foundation

public struct NotificationEntry: Codable, Equatable, Sendable {
    public let session_id: String
    public let terminal_id: String
    public let working_dir: String
    public let cwd: String
    public let name: String
    public var message: String
    public var timestamp: String

    public init(
        session_id: String, terminal_id: String, working_dir: String,
        cwd: String, name: String, message: String, timestamp: String
    ) {
        self.session_id = session_id
        self.terminal_id = terminal_id
        self.working_dir = working_dir
        self.cwd = cwd
        self.name = name
        self.message = message
        self.timestamp = timestamp
    }
}

public struct SessionEntry: Codable, Equatable, Sendable {
    public let terminal_id: String
    public let name: String
    public let working_dir: String
    public let cwd: String
    public let started_at: String

    public init(
        terminal_id: String, name: String, working_dir: String,
        cwd: String, started_at: String
    ) {
        self.terminal_id = terminal_id
        self.name = name
        self.working_dir = working_dir
        self.cwd = cwd
        self.started_at = started_at
    }
}

public struct HookInput: Codable, Sendable {
    public let session_id: String?
    public let cwd: String?
    public let message: String?
    public let hook_event_name: String?

    public init(session_id: String? = nil, cwd: String? = nil, message: String? = nil, hook_event_name: String? = nil) {
        self.session_id = session_id
        self.cwd = cwd
        self.message = message
        self.hook_event_name = hook_event_name
    }
}
