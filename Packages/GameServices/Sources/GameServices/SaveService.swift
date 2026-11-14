import Foundation

/// Where a save is stored. Local file storage is always used; iCloud is optional.
public protocol SaveStore: Sendable {
    func read(_ key: String) -> Data?
    func write(_ data: Data, for key: String)
    func remove(_ key: String)
}

/// JSON files in Application Support. Writes are atomic so a crash never corrupts a save.
public struct FileSaveStore: SaveStore {
    public let directory: URL

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Saves", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    private func url(_ key: String) -> URL { directory.appendingPathComponent("\(key).json") }

    public func read(_ key: String) -> Data? { try? Data(contentsOf: url(key)) }
    public func write(_ data: Data, for key: String) { try? data.write(to: url(key), options: .atomic) }
    public func remove(_ key: String) { try? FileManager.default.removeItem(at: url(key)) }
}

/// In-memory store for tests and previews.
public final class MemorySaveStore: SaveStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()
    public init() {}
    public func read(_ key: String) -> Data? { lock.withLock { storage[key] } }
    public func write(_ data: Data, for key: String) { lock.withLock { storage[key] = data } }
    public func remove(_ key: String) { _ = lock.withLock { storage.removeValue(forKey: key) } }
}

#if canImport(UIKit) || os(macOS)
/// iCloud key-value store (max 1 MB total, 1 MB per key) — plenty for progress saves.
public struct UbiquitousSaveStore: SaveStore {
    public init() {}
    public func read(_ key: String) -> Data? { NSUbiquitousKeyValueStore.default.data(forKey: key) }
    public func write(_ data: Data, for key: String) {
        NSUbiquitousKeyValueStore.default.set(data, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    public func remove(_ key: String) { NSUbiquitousKeyValueStore.default.removeObject(forKey: key) }
}
#endif

/// Typed save/load with optional cloud sync and a game-provided merge for conflicts.
@MainActor
public final class SaveService<Value: Codable & Sendable> {
    private let key: String
    private let local: SaveStore
    private let cloud: SaveStore?
    private let merge: (Value, Value) -> Value
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(key: String, local: SaveStore, cloud: SaveStore? = nil,
                merge: @escaping (Value, Value) -> Value) {
        self.key = key
        self.local = local
        self.cloud = cloud
        self.merge = merge
    }

    /// Loads the local save, merged with the iCloud copy when both exist.
    public func load() -> Value? {
        let localValue = local.read(key).flatMap { try? decoder.decode(Value.self, from: $0) }
        let cloudValue = cloud?.read(key).flatMap { try? decoder.decode(Value.self, from: $0) }
        switch (localValue, cloudValue) {
        case let (l?, c?): return merge(l, c)
        case let (l?, nil): return l
        case let (nil, c?): return c
        default: return nil
        }
    }

    public func save(_ value: Value) {
        guard let data = try? encoder.encode(value) else { return }
        local.write(data, for: key)
        cloud?.write(data, for: key)
    }

    /// Call when iCloud reports an external change; returns the merged value to adopt.
    public func mergeCloudChange(into current: Value) -> Value {
        guard let data = cloud?.read(key), let remote = try? decoder.decode(Value.self, from: data) else { return current }
        let merged = merge(current, remote)
        save(merged)
        return merged
    }

    public func reset() {
        local.remove(key)
        cloud?.remove(key)
    }
}
