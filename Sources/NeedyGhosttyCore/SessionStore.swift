import Foundation

public final class SessionStore {
    public let filePath: String
    public let lock: FileLock

    public init(dataDir: String, lock: FileLock? = nil) {
        self.filePath = (dataDir as NSString).appendingPathComponent("session-map.json")
        self.lock = lock ?? FileLock()
        try? FileManager.default.createDirectory(
            atPath: dataDir, withIntermediateDirectories: true)
    }

    public func load() -> [String: SessionEntry] {
        guard let data = FileManager.default.contents(atPath: filePath) else { return [:] }
        return (try? JSONDecoder().decode([String: SessionEntry].self, from: data)) ?? [:]
    }

    public func save(_ map: [String: SessionEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(map) else { return }
        atomicWrite(data: data)
    }

    public func set(sessionId: String, entry: SessionEntry) {
        guard lock.acquire() else { return }
        defer { lock.release() }

        var map = load()
        map[sessionId] = entry
        save(map)
    }

    public func get(sessionId: String) -> SessionEntry? {
        load()[sessionId]
    }

    private func atomicWrite(data: Data) {
        let dir = (filePath as NSString).deletingLastPathComponent
        let tmp = (dir as NSString).appendingPathComponent("tmp-\(UUID().uuidString).json")
        let tmpURL = URL(fileURLWithPath: tmp)
        let targetURL = URL(fileURLWithPath: filePath)

        do {
            try data.write(to: tmpURL)
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: tmpURL)
        } catch {
            try? data.write(to: targetURL)
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }
}
