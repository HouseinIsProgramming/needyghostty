import Foundation

public struct FileLock {
    public let path: String

    public init(path: String = "/tmp/needyghostty.lock") {
        self.path = path
    }

    public func acquire(maxAttempts: Int = 100, sleepMicroseconds: UInt32 = 50_000, staleSeconds: TimeInterval = 10) -> Bool {
        for attempt in 0..<maxAttempts {
            do {
                try FileManager.default.createDirectory(
                    atPath: path, withIntermediateDirectories: false)
                return true
            } catch {
                if attempt % 10 == 0,
                   let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                   let modDate = attrs[.modificationDate] as? Date,
                   Date().timeIntervalSince(modDate) > staleSeconds
                {
                    try? FileManager.default.removeItem(atPath: path)
                    continue
                }
                usleep(sleepMicroseconds)
            }
        }
        return false
    }

    public func release() {
        try? FileManager.default.removeItem(atPath: path)
    }
}
