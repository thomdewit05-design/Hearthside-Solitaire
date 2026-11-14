import Foundation

/// A typed Remote Config key with a local default, declared by each game.
public struct ConfigKey<Value: Sendable>: Sendable, Hashable {
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    public static func == (lhs: ConfigKey, rhs: ConfigKey) -> Bool { lhs.name == rhs.name }
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

/// Raw value source (Firebase Remote Config in production, a dictionary in tests/debug).
public protocol ConfigValueSource: Sendable {
    func value(for name: String) -> String?
}

public struct DictionaryConfigSource: ConfigValueSource {
    public var values: [String: String]
    public init(_ values: [String: String] = [:]) { self.values = values }
    public func value(for name: String) -> String? { values[name] }
}

/// Reads typed values with fallbacks; never crashes on bad remote data.
@MainActor
public final class ConfigService {
    public private(set) var source: ConfigValueSource
    /// Debug-menu overrides win over remote values.
    public var overrides: [String: String] = [:]

    public init(source: ConfigValueSource = DictionaryConfigSource()) {
        self.source = source
    }

    public func update(source: ConfigValueSource) {
        self.source = source
    }

    private func raw(_ name: String) -> String? {
        overrides[name] ?? source.value(for: name)
    }

    public func value(_ key: ConfigKey<Int>) -> Int { raw(key.name).flatMap { Int($0) } ?? key.defaultValue }
    public func value(_ key: ConfigKey<Double>) -> Double { raw(key.name).flatMap { Double($0) } ?? key.defaultValue }
    public func value(_ key: ConfigKey<String>) -> String { raw(key.name) ?? key.defaultValue }
    public func value(_ key: ConfigKey<Bool>) -> Bool {
        guard let text = raw(key.name)?.lowercased() else { return key.defaultValue }
        switch text {
        case "true", "1", "yes", "on": return true
        case "false", "0", "no", "off": return false
        default: return key.defaultValue
        }
    }
}
