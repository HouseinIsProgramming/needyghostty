import Foundation

public final class NotificationStore {
    public let filePath: String
    public let lock: FileLock

    public init(dataDir: String, lock: FileLock? = nil) {
        self.filePath = (dataDir as NSString).appendingPathComponent("notifications.json")
        self.lock = lock ?? FileLock()
        try? FileManager.default.createDirectory(
            atPath: dataDir, withIntermediateDirectories: true)
    }

    public func load() -> [NotificationEntry] {
        guard let data = FileManager.default.contents(atPath: filePath) else { return [] }
        return (try? JSONDecoder().decode([NotificationEntry].self, from: data)) ?? []
    }

    public func save(_ entries: [NotificationEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        atomicWrite(data: data)
    }

    public func addOrUpdate(_ entry: NotificationEntry) {
        guard lock.acquire() else { return }
        defer { lock.release() }

        var entries = load()
        if let idx = entries.firstIndex(where: { $0.session_id == entry.session_id }) {
            entries[idx].message = entry.message
            entries[idx].timestamp = entry.timestamp
        } else {
            entries.append(entry)
        }
        save(entries)
    }

    public func remove(sessionId: String) {
        guard lock.acquire() else { return }
        defer { lock.release() }

        var entries = load()
        entries.removeAll { $0.session_id == sessionId }
        save(entries)
    }

    public func clear() {
        guard lock.acquire() else { return }
        defer { lock.release() }
        save([])
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
