import Foundation
import Testing

@testable import NeedyGhosttyCore

@Suite("HookHandler")
struct HookHandlerTests {
    func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "needyghostty-test-\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    func makeLock(_ dir: String) -> FileLock {
        FileLock(path: dir + "/test.lock")
    }

    @Test func notificationWithoutSessionIsIgnored() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lock = makeLock(dir)
        let notifStore = NotificationStore(dataDir: dir, lock: lock)
        let sessStore = SessionStore(dataDir: dir, lock: lock)
        let handler = HookHandler(sessionStore: sessStore, notificationStore: notifStore)

        let input = HookInput(session_id: "s1", message: "Needs input")
        handler.handleNotification(input: input)

        #expect(notifStore.load().isEmpty)
    }

    @Test func notificationWithSessionCreatesEntry() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lock = makeLock(dir)
        let notifStore = NotificationStore(dataDir: dir, lock: lock)
        let sessStore = SessionStore(dataDir: dir, lock: lock)
        let handler = HookHandler(sessionStore: sessStore, notificationStore: notifStore)

        // Pre-populate session
        let session = SessionEntry(
            terminal_id: "t1", name: "zsh",
            working_dir: "/home", cwd: "/project",
            started_at: "2025-01-01T00:00:00Z")
        sessStore.set(sessionId: "s1", entry: session)

        let input = HookInput(session_id: "s1", message: "Needs permission")
        handler.handleNotification(input: input)

        let loaded = notifStore.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].session_id == "s1")
        #expect(loaded[0].terminal_id == "t1")
        #expect(loaded[0].message == "Needs permission")
    }

    @Test func userPromptSubmitRemovesNotification() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lock = makeLock(dir)
        let notifStore = NotificationStore(dataDir: dir, lock: lock)
        let sessStore = SessionStore(dataDir: dir, lock: lock)
        let handler = HookHandler(sessionStore: sessStore, notificationStore: notifStore)

        // Pre-populate session and notification
        let session = SessionEntry(
            terminal_id: "t1", name: "zsh",
            working_dir: "/home", cwd: "/project",
            started_at: "2025-01-01T00:00:00Z")
        sessStore.set(sessionId: "s1", entry: session)

        let notifInput = HookInput(session_id: "s1", message: "Waiting")
        handler.handleNotification(input: notifInput)
        #expect(notifStore.load().count == 1)

        let dismissInput = HookInput(session_id: "s1")
        handler.handleUserPromptSubmit(input: dismissInput)
        #expect(notifStore.load().isEmpty)
    }

    @Test func emptySessionIdIsIgnored() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lock = makeLock(dir)
        let notifStore = NotificationStore(dataDir: dir, lock: lock)
        let sessStore = SessionStore(dataDir: dir, lock: lock)
        let handler = HookHandler(sessionStore: sessStore, notificationStore: notifStore)

        handler.handleNotification(input: HookInput(session_id: ""))
        handler.handleUserPromptSubmit(input: HookInput(session_id: ""))
        handler.handleSessionStart(input: HookInput(session_id: ""))

        #expect(notifStore.load().isEmpty)
    }

    @Test func notificationDefaultMessage() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lock = makeLock(dir)
        let notifStore = NotificationStore(dataDir: dir, lock: lock)
        let sessStore = SessionStore(dataDir: dir, lock: lock)
        let handler = HookHandler(sessionStore: sessStore, notificationStore: notifStore)

        let session = SessionEntry(
            terminal_id: "t1", name: "zsh",
            working_dir: "/home", cwd: "/project",
            started_at: "2025-01-01T00:00:00Z")
        sessStore.set(sessionId: "s1", entry: session)

        handler.handleNotification(input: HookInput(session_id: "s1"))

        let loaded = notifStore.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].message == "Waiting for input")
    }

    @Test func multipleSessionsFullFlow() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lock = makeLock(dir)
        let notifStore = NotificationStore(dataDir: dir, lock: lock)
        let sessStore = SessionStore(dataDir: dir, lock: lock)
        let handler = HookHandler(sessionStore: sessStore, notificationStore: notifStore)

        // Register 3 sessions
        for i in 1...3 {
            let session = SessionEntry(
                terminal_id: "t\(i)", name: "zsh",
                working_dir: "/home", cwd: "/project\(i)",
                started_at: "2025-01-01T00:00:0\(i)Z")
            sessStore.set(sessionId: "s\(i)", entry: session)
        }

        // Notifications for all 3
        for i in 1...3 {
            handler.handleNotification(input: HookInput(session_id: "s\(i)", message: "msg\(i)"))
        }
        #expect(notifStore.load().count == 3)

        // Dismiss s2
        handler.handleUserPromptSubmit(input: HookInput(session_id: "s2"))
        let remaining = notifStore.load()
        #expect(remaining.count == 2)
        #expect(!remaining.contains(where: { $0.session_id == "s2" }))
    }
}
