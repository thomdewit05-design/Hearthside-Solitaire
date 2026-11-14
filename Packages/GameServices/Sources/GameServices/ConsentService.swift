import Foundation

/// Privacy consent state that decides whether (personalised) ads may be requested.
public struct ConsentState: Sendable, Equatable {
    public var canRequestAds: Bool
    public var privacyOptionsRequired: Bool
    public var trackingAuthorized: Bool

    public init(canRequestAds: Bool = false, privacyOptionsRequired: Bool = false, trackingAuthorized: Bool = false) {
        self.canRequestAds = canRequestAds
        self.privacyOptionsRequired = privacyOptionsRequired
        self.trackingAuthorized = trackingAuthorized
    }
}

@MainActor
public protocol ConsentServicing: AnyObject {
    var state: ConsentState { get }
    /// UMP form (EEA/UK) first, then the ATT prompt. Never shown mid-game.
    func gatherConsent() async -> ConsentState
    /// "Privacy settings" button in Settings (required when `privacyOptionsRequired`).
    func presentPrivacyOptions() async
}

@MainActor
public final class FakeConsentService: ConsentServicing {
    public private(set) var state = ConsentState(canRequestAds: true)
    public init() {}
    public func gatherConsent() async -> ConsentState { state }
    public func presentPrivacyOptions() async {}
}
