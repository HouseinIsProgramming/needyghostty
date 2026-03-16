import Foundation

public final class HookHandler {
    private let sessionStore: SessionStore
    private let notificationStore: NotificationStore
    private let ghostty: GhosttyBridge

    public init(dataDir: String, lock: FileLock? = nil) {
        let lock = lock ?? FileLock()
        self.sessionStore = SessionStore(dataDir: dataDir, lock: lock)
        self.notificationStore = NotificationStore(dataDir: dataDir, lock: lock)
        self.ghostty = GhosttyBridge()
    }

    public init(sessionStore: SessionStore, notificationStore: NotificationStore, ghostty: GhosttyBridge = GhosttyBridge()) {
        self.sessionStore = sessionStore
        self.notificationStore = notificationStore
        self.ghostty = ghostty
    }

    public func handleSessionStart(input: HookInput) {
        guard let sessionId = input.session_id, !sessionId.isEmpty else { return }

        guard let info = ghostty.getFocusedTerminalInfo() else { return }

        let entry = SessionEntry(
            terminal_id: info.id,
            name: info.name,
            working_dir: info.workingDir,
            cwd: input.cwd ?? "",
            started_at: isoTimestamp()
        )
        sessionStore.set(sessionId: sessionId, entry: entry)
    }

    public func handleNotification(input: HookInput) {
        guard let sessionId = input.session_id, !sessionId.isEmpty else { return }
        guard let session = sessionStore.get(sessionId: sessionId) else { return }

        let message = input.message ?? "Waiting for input"
        let entry = NotificationEntry(
            session_id: sessionId,
            terminal_id: session.terminal_id,
            working_dir: session.working_dir,
            cwd: session.cwd,
            name: session.name,
            message: message,
            timestamp: isoTimestamp()
        )
        notificationStore.addOrUpdate(entry)
    }

    public func handleUserPromptSubmit(input: HookInput) {
        guard let sessionId = input.session_id, !sessionId.isEmpty else { return }
        notificationStore.remove(sessionId: sessionId)
    }
}
