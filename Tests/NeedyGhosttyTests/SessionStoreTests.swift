import Foundation
import Testing

@testable import NeedyGhosttyCore

@Suite("SessionStore")
struct SessionStoreTests {
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

    @Test func loadEmptyReturnsEmpty() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = SessionStore(dataDir: dir, lock: makeLock(dir))
        #expect(store.load().isEmpty)
    }

    @Test func setAndGet() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = SessionStore(dataDir: dir, lock: makeLock(dir))

        let entry = SessionEntry(
            terminal_id: "t1", name: "zsh",
            working_dir: "/home", cwd: "/project",
            started_at: "2025-01-01T00:00:00Z")

        store.set(sessionId: "s1", entry: entry)

        let loaded = store.get(sessionId: "s1")
        #expect(loaded == entry)
    }

    @Test func getMissingReturnsNil() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = SessionStore(dataDir: dir, lock: makeLock(dir))
        #expect(store.get(sessionId: "nonexistent") == nil)
    }

    @Test func setOverwritesExisting() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = SessionStore(dataDir: dir, lock: makeLock(dir))

        let e1 = SessionEntry(
            terminal_id: "t1", name: "zsh",
            working_dir: "/d", cwd: "/c",
            started_at: "2025-01-01T00:00:00Z")
        let e2 = SessionEntry(
            terminal_id: "t2", name: "bash",
            working_dir: "/d2", cwd: "/c2",
            started_at: "2025-01-01T00:01:00Z")

        store.set(sessionId: "s1", entry: e1)
        store.set(sessionId: "s1", entry: e2)

        let loaded = store.get(sessionId: "s1")
        #expect(loaded == e2)
        #expect(store.load().count == 1)
    }

    @Test func multipleSessions() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = SessionStore(dataDir: dir, lock: makeLock(dir))

        for i in 0..<5 {
            let entry = SessionEntry(
                terminal_id: "t\(i)", name: "zsh",
                working_dir: "/d", cwd: "/c",
                started_at: "2025-01-01T00:00:0\(i)Z")
            store.set(sessionId: "s\(i)", entry: entry)
        }

        #expect(store.load().count == 5)
        #expect(store.get(sessionId: "s3")?.terminal_id == "t3")
    }
}
