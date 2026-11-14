import Foundation

/// Frequency rules for ads. Pure logic so it can be unit-tested; the numbers come
/// from Remote Config.
public struct AdRules: Codable, Hashable, Sendable {
    /// First round after which an interstitial may appear (1-based). Plan: from round 4.
    public var interstitialFirstRound: Int
    /// Minimum time between two interstitials.
    public var interstitialMinInterval: TimeInterval
    /// No interstitial within this time after a rewarded ad.
    public var cooldownAfterRewarded: TimeInterval
    public var rewardedDailyCap: Int
    public var interstitialsEnabled: Bool
    public var bannersEnabled: Bool

    public init(interstitialFirstRound: Int = 4,
                interstitialMinInterval: TimeInterval = 180,
                cooldownAfterRewarded: TimeInterval = 120,
                rewardedDailyCap: Int = 15,
                interstitialsEnabled: Bool = true,
                bannersEnabled: Bool = true) {
        self.interstitialFirstRound = interstitialFirstRound
        self.interstitialMinInterval = interstitialMinInterval
        self.cooldownAfterRewarded = cooldownAfterRewarded
        self.rewardedDailyCap = rewardedDailyCap
        self.interstitialsEnabled = interstitialsEnabled
        self.bannersEnabled = bannersEnabled
    }
}

/// Persistent counters the rules are evaluated against.
public struct AdLedger: Codable, Hashable, Sendable {
    public var roundsCompleted = 0
    public var lastInterstitialAt: Date?
    public var lastRewardedAt: Date?
    public var rewardedToday = 0
    /// "yyyy-MM-dd" of the day `rewardedToday` counts.
    public var rewardedDay: String?

    public init() {}
}

public enum InterstitialDecision: Equatable, Sendable {
    case show
    case skip(Reason)

    public enum Reason: String, Sendable {
        case adsRemoved, disabled, tooEarlyInSession, tooSoonAfterLast, justWatchedRewarded, midGame
    }
}

public struct AdPolicy: Sendable {
    public var rules: AdRules

    public init(rules: AdRules) {
        self.rules = rules
    }

    /// Call when a round ends (win or give up), before dealing the next one.
    /// `isBetweenRounds` must be true — interstitials are never shown during a game.
    public func interstitialDecision(ledger: AdLedger, now: Date, adsRemoved: Bool,
                                     isBetweenRounds: Bool) -> InterstitialDecision {
        if adsRemoved { return .skip(.adsRemoved) }
        if !rules.interstitialsEnabled { return .skip(.disabled) }
        if !isBetweenRounds { return .skip(.midGame) }
        if ledger.roundsCompleted < rules.interstitialFirstRound { return .skip(.tooEarlyInSession) }
        if let last = ledger.lastRewardedAt, now.timeIntervalSince(last) < rules.cooldownAfterRewarded {
            return .skip(.justWatchedRewarded)
        }
        if let last = ledger.lastInterstitialAt, now.timeIntervalSince(last) < rules.interstitialMinInterval {
            return .skip(.tooSoonAfterLast)
        }
        return .show
    }

    public func canShowRewarded(ledger: AdLedger, today: String) -> Bool {
        rewardedCount(ledger: ledger, today: today) < rules.rewardedDailyCap
    }

    public func rewardedCount(ledger: AdLedger, today: String) -> Int {
        ledger.rewardedDay == today ? ledger.rewardedToday : 0
    }

    public func bannerAllowed(adsRemoved: Bool, onGameTable: Bool) -> Bool {
        !adsRemoved && rules.bannersEnabled && !onGameTable
    }
}

public extension AdLedger {
    mutating func recordRoundCompleted() { roundsCompleted += 1 }

    mutating func recordInterstitial(at date: Date) { lastInterstitialAt = date }

    mutating func recordRewarded(at date: Date, today: String) {
        if rewardedDay != today {
            rewardedDay = today
            rewardedToday = 0
        }
        rewardedToday += 1
        lastRewardedAt = date
    }
}
