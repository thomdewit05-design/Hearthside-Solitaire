import Foundation

public enum AdFormat: String, Sendable, Codable {
    case interstitial, rewarded, banner
}

/// Ad unit IDs per game. Use Google's test IDs in Debug builds.
public struct AdUnitIDs: Sendable, Hashable {
    public var interstitial: String
    public var rewarded: String
    public var banner: String

    public init(interstitial: String, rewarded: String, banner: String) {
        self.interstitial = interstitial
        self.rewarded = rewarded
        self.banner = banner
    }

    /// Google's public test units — safe to click, never earn money.
    public static let googleTest = AdUnitIDs(interstitial: "ca-app-pub-3940256099942544/4411468910",
                                             rewarded: "ca-app-pub-3940256099942544/1712485313",
                                             banner: "ca-app-pub-3940256099942544/2435281174")
}

/// Revenue of one impression, as reported by the network (paid event).
public struct AdRevenue: Sendable, Equatable {
    public var format: AdFormat
    public var valueMicros: Int64
    public var currency: String
    public var placement: String

    public init(format: AdFormat, valueMicros: Int64, currency: String, placement: String) {
        self.format = format
        self.valueMicros = valueMicros
        self.currency = currency
        self.placement = placement
    }
}

/// The ad network adapter (Google Mobile Ads in production, a fake in tests/simulator).
@MainActor
public protocol AdNetwork: AnyObject {
    func start() async
    func preload(_ format: AdFormat) async
    func isReady(_ format: AdFormat) -> Bool
    /// Shows an interstitial; returns when it is dismissed.
    func showInterstitial(placement: String) async -> Bool
    /// Shows a rewarded ad; returns true when the user earned the reward.
    func showRewarded(placement: String) async -> Bool
    var onRevenue: ((AdRevenue) -> Void)? { get set }
}

/// Game-facing ad API: applies `AdPolicy`, keeps the ledger and logs every impression.
@MainActor
public final class AdService {
    public private(set) var ledger: AdLedger
    public var policy: AdPolicy
    public var adsRemoved: Bool
    private let network: AdNetwork
    private let analytics: AnalyticsService?
    private let persist: (AdLedger) -> Void
    private let now: () -> Date
    private let dayString: (Date) -> String

    public init(network: AdNetwork,
                rules: AdRules,
                ledger: AdLedger = AdLedger(),
                adsRemoved: Bool = false,
                analytics: AnalyticsService? = nil,
                persist: @escaping (AdLedger) -> Void = { _ in },
                now: @escaping () -> Date = Date.init,
                dayString: @escaping (Date) -> String = AdService.localDayString) {
        self.network = network
        self.policy = AdPolicy(rules: rules)
        self.ledger = ledger
        self.adsRemoved = adsRemoved
        self.analytics = analytics
        self.persist = persist
        self.now = now
        self.dayString = dayString
        network.onRevenue = { [weak analytics] revenue in
            analytics?.log("ad_impression", [
                "format": revenue.format.rawValue,
                "placement": revenue.placement,
                "value_micros": String(revenue.valueMicros),
                "currency": revenue.currency
            ])
        }
    }

    public nonisolated static func localDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public func start() async {
        await network.start()
        await network.preload(.rewarded)
        if !adsRemoved { await network.preload(.interstitial) }
    }

    /// Call exactly once when a round ends (won or abandoned), before the next deal.
    /// Shows an interstitial only if every rule allows it. Returns true if one was shown.
    @discardableResult
    public func roundDidEnd(placement: String = "between_rounds") async -> Bool {
        ledger.recordRoundCompleted()
        persist(ledger)
        let decision = policy.interstitialDecision(ledger: ledger, now: now(), adsRemoved: adsRemoved,
                                                   isBetweenRounds: true)
        guard decision == .show, network.isReady(.interstitial) else {
            if case .skip(let reason) = decision {
                analytics?.log("interstitial_skipped", ["reason": reason.rawValue])
            }
            if !adsRemoved { Task { await network.preload(.interstitial) } }
            return false
        }
        let shown = await network.showInterstitial(placement: placement)
        if shown {
            ledger.recordInterstitial(at: now())
            persist(ledger)
        }
        Task { await network.preload(.interstitial) }
        return shown
    }

    public var rewardedAvailable: Bool {
        policy.canShowRewarded(ledger: ledger, today: dayString(now())) && network.isReady(.rewarded)
    }

    public var rewardedRemainingToday: Int {
        max(0, policy.rules.rewardedDailyCap - policy.rewardedCount(ledger: ledger, today: dayString(now())))
    }

    /// Always optional: only call from an explicit player tap. Returns true when the reward was earned.
    public func showRewarded(placement: String) async -> Bool {
        guard policy.canShowRewarded(ledger: ledger, today: dayString(now())) else { return false }
        let earned = await network.showRewarded(placement: placement)
        if earned {
            ledger.recordRewarded(at: now(), today: dayString(now()))
            persist(ledger)
            analytics?.log("rewarded_earned", ["placement": placement])
        }
        Task { await network.preload(.rewarded) }
        return earned
    }

    public func bannerAllowed(onGameTable: Bool) -> Bool {
        policy.bannerAllowed(adsRemoved: adsRemoved, onGameTable: onGameTable)
    }
}

/// Simulator / debug network: instantly "shows" ads and always rewards.
@MainActor
public final class FakeAdNetwork: AdNetwork {
    public var ready: Set<AdFormat> = [.interstitial, .rewarded, .banner]
    public var shown: [(AdFormat, String)] = []
    public var rewardsUser = true
    public var onRevenue: ((AdRevenue) -> Void)?

    public init() {}

    public func start() async {}
    public func preload(_ format: AdFormat) async { ready.insert(format) }
    public func isReady(_ format: AdFormat) -> Bool { ready.contains(format) }

    public func showInterstitial(placement: String) async -> Bool {
        shown.append((.interstitial, placement))
        onRevenue?(AdRevenue(format: .interstitial, valueMicros: 0, currency: "USD", placement: placement))
        return true
    }

    public func showRewarded(placement: String) async -> Bool {
        shown.append((.rewarded, placement))
        onRevenue?(AdRevenue(format: .rewarded, valueMicros: 0, currency: "USD", placement: placement))
        return rewardsUser
    }
}
