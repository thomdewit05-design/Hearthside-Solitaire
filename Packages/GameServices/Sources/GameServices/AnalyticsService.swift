import Foundation

public protocol AnalyticsSink: Sendable {
    func log(_ event: String, _ parameters: [String: String])
    func setUserProperty(_ value: String?, for name: String)
}

/// Prints events in Debug builds; handy with the debug menu.
public struct ConsoleAnalyticsSink: AnalyticsSink {
    public init() {}
    public func log(_ event: String, _ parameters: [String: String]) {
        #if DEBUG
        let params = parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("📊 \(event) \(params)")
        #endif
    }
    public func setUserProperty(_ value: String?, for name: String) {}
}

/// Fans events out to every sink (Firebase + console). Event names are snake_case, max 40 chars.
@MainActor
public final class AnalyticsService {
    private var sinks: [AnalyticsSink]
    public private(set) var recent: [(String, [String: String])] = []
    public var isEnabled = true

    public init(sinks: [AnalyticsSink] = [ConsoleAnalyticsSink()]) {
        self.sinks = sinks
    }

    public func add(_ sink: AnalyticsSink) { sinks.append(sink) }

    public func log(_ event: String, _ parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        precondition(event.count <= 40, "Analytics event names are limited to 40 characters")
        recent.append((event, parameters))
        if recent.count > 100 { recent.removeFirst() }
        sinks.forEach { $0.log(event, parameters) }
    }

    public func setUserProperty(_ value: String?, for name: String) {
        sinks.forEach { $0.setUserProperty(value, for: name) }
    }
}
