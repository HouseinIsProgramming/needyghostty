import Foundation
import Testing

@testable import NeedyGhosttyCore

@Suite("NotificationStore")
struct NotificationStoreTests {
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
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))
        #expect(store.load().isEmpty)
    }

    @Test func saveAndLoad() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))

        let entry = NotificationEntry(
            session_id: "s1", terminal_id: "t1",
            working_dir: "/dir", cwd: "/cwd",
            name: "zsh", message: "Waiting",
            timestamp: "2025-01-01T00:00:00Z")
        store.save([entry])

        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded[0] == entry)
    }

    @Test func addOrUpdateAppendsNew() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))

        let e1 = NotificationEntry(
            session_id: "s1", terminal_id: "t1",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "m1",
            timestamp: "2025-01-01T00:00:00Z")
        let e2 = NotificationEntry(
            session_id: "s2", terminal_id: "t2",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "m2",
            timestamp: "2025-01-01T00:00:01Z")

        store.addOrUpdate(e1)
        store.addOrUpdate(e2)

        let loaded = store.load()
        #expect(loaded.count == 2)
    }

    @Test func addOrUpdateDeduplicatesBySessionId() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))

        let e1 = NotificationEntry(
            session_id: "s1", terminal_id: "t1",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "first",
            timestamp: "2025-01-01T00:00:00Z")
        store.addOrUpdate(e1)

        let e2 = NotificationEntry(
            session_id: "s1", terminal_id: "t1",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "updated",
            timestamp: "2025-01-01T00:01:00Z")
        store.addOrUpdate(e2)

        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].message == "updated")
        #expect(loaded[0].timestamp == "2025-01-01T00:01:00Z")
    }

    @Test func removeBySessionId() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))

        let e1 = NotificationEntry(
            session_id: "s1", terminal_id: "t1",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "m",
            timestamp: "2025-01-01T00:00:00Z")
        let e2 = NotificationEntry(
            session_id: "s2", terminal_id: "t2",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "m",
            timestamp: "2025-01-01T00:00:01Z")
        store.save([e1, e2])

        store.remove(sessionId: "s1")
        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].session_id == "s2")
    }

    @Test func clearRemovesAll() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))

        let e = NotificationEntry(
            session_id: "s1", terminal_id: "t1",
            working_dir: "/d", cwd: "/c",
            name: "z", message: "m",
            timestamp: "2025-01-01T00:00:00Z")
        store.save([e])
        store.clear()
        #expect(store.load().isEmpty)
    }

    @Test func concurrentWritesSafe() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = NotificationStore(dataDir: dir, lock: makeLock(dir))

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let entry = NotificationEntry(
                        session_id: "s\(i)", terminal_id: "t\(i)",
                        working_dir: "/d", cwd: "/c",
                        name: "z", message: "m\(i)",
                        timestamp: "2025-01-01T00:00:0\(i % 10)Z")
                    store.addOrUpdate(entry)
                }
            }
        }

        let loaded = store.load()
        #expect(loaded.count == 10)
    }

    @Test func staleLockRecovery() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let lockPath = dir + "/stale.lock"

        // Create a stale lock with old modification date
        try! FileManager.default.createDirectory(atPath: lockPath, withIntermediateDirectories: false)
        let past = Date().addingTimeInterval(-30)
        try! FileManager.default.setAttributes(
            [.modificationDate: past], ofItemAtPath: lockPath)

        let lock = FileLock(path: lockPath)
        #expect(lock.acquire(staleSeconds: 10))
        lock.release()
    }
}
