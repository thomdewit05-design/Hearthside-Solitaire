import XCTest
@testable import GameServices

final class AdPolicyTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let policy = AdPolicy(rules: AdRules())

    func ledger(rounds: Int, lastInterstitial: TimeInterval? = nil, lastRewarded: TimeInterval? = nil) -> AdLedger {
        var ledger = AdLedger()
        ledger.roundsCompleted = rounds
        ledger.lastInterstitialAt = lastInterstitial.map { start.addingTimeInterval(-$0) }
        ledger.lastRewardedAt = lastRewarded.map { start.addingTimeInterval(-$0) }
        return ledger
    }

    func testNoInterstitialBeforeRoundFour() {
        for rounds in 0..<4 {
            XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: rounds), now: start, adsRemoved: false,
                                                       isBetweenRounds: true), .skip(.tooEarlyInSession))
        }
        XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: 4), now: start, adsRemoved: false,
                                                   isBetweenRounds: true), .show)
    }

    func testMinimumThreeMinutesBetweenInterstitials() {
        XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: 9, lastInterstitial: 179), now: start,
                                                   adsRemoved: false, isBetweenRounds: true), .skip(.tooSoonAfterLast))
        XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: 9, lastInterstitial: 180), now: start,
                                                   adsRemoved: false, isBetweenRounds: true), .show)
    }

    func testNeverRightAfterRewarded() {
        XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: 9, lastRewarded: 30), now: start,
                                                   adsRemoved: false, isBetweenRounds: true), .skip(.justWatchedRewarded))
    }

    func testNeverMidGameOrWithRemoveAds() {
        XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: 9), now: start, adsRemoved: false,
                                                   isBetweenRounds: false), .skip(.midGame))
        XCTAssertEqual(policy.interstitialDecision(ledger: ledger(rounds: 9), now: start, adsRemoved: true,
                                                   isBetweenRounds: true), .skip(.adsRemoved))
        var rules = AdRules()
        rules.interstitialsEnabled = false
        XCTAssertEqual(AdPolicy(rules: rules).interstitialDecision(ledger: ledger(rounds: 9), now: start,
                                                                   adsRemoved: false, isBetweenRounds: true),
                       .skip(.disabled))
    }

    func testRewardedDailyCapResetsEachDay() {
        var ledger = AdLedger()
        for _ in 0..<15 {
            XCTAssertTrue(policy.canShowRewarded(ledger: ledger, today: "2026-11-14"))
            ledger.recordRewarded(at: start, today: "2026-11-14")
        }
        XCTAssertFalse(policy.canShowRewarded(ledger: ledger, today: "2026-11-14"))
        XCTAssertTrue(policy.canShowRewarded(ledger: ledger, today: "2026-11-15"))
        ledger.recordRewarded(at: start, today: "2026-11-15")
        XCTAssertEqual(ledger.rewardedToday, 1)
    }

    func testBanners() {
        XCTAssertTrue(policy.bannerAllowed(adsRemoved: false, onGameTable: false))
        XCTAssertFalse(policy.bannerAllowed(adsRemoved: false, onGameTable: true), "never on the table")
        XCTAssertFalse(policy.bannerAllowed(adsRemoved: true, onGameTable: false))
    }
}

@MainActor
final class AdServiceTests: XCTestCase {
    func testRoundFlowShowsInterstitialFromRoundFour() async {
        let network = FakeAdNetwork()
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        var persisted: AdLedger?
        let service = AdService(network: network, rules: AdRules(), persist: { persisted = $0 }, now: { clock })
        for _ in 0..<3 {
            let shown = await service.roundDidEnd()
            XCTAssertFalse(shown)
        }
        let fourth = await service.roundDidEnd()
        XCTAssertTrue(fourth)
        clock.addTimeInterval(60)
        let tooSoon = await service.roundDidEnd()
        XCTAssertFalse(tooSoon)
        clock.addTimeInterval(200)
        let again = await service.roundDidEnd()
        XCTAssertTrue(again)
        XCTAssertEqual(network.shown.filter { $0.0 == .interstitial }.count, 2)
        XCTAssertEqual(persisted?.roundsCompleted, 6)
    }

    func testRewardedThenNoInterstitial() async {
        let network = FakeAdNetwork()
        let clock = Date(timeIntervalSince1970: 1_800_000_000)
        var ledger = AdLedger()
        ledger.roundsCompleted = 10
        let analytics = AnalyticsService(sinks: [])
        let service = AdService(network: network, rules: AdRules(), ledger: ledger, analytics: analytics, now: { clock })
        XCTAssertTrue(service.rewardedAvailable)
        let earned = await service.showRewarded(placement: "double_warmth")
        XCTAssertTrue(earned)
        XCTAssertEqual(service.rewardedRemainingToday, 14)
        let shown = await service.roundDidEnd()
        XCTAssertFalse(shown)
        XCTAssertTrue(analytics.recent.contains { $0.0 == "rewarded_earned" })
        XCTAssertTrue(analytics.recent.contains { $0.0 == "ad_impression" })
    }

    func testRemoveAdsKeepsRewarded() async {
        let network = FakeAdNetwork()
        var ledger = AdLedger()
        ledger.roundsCompleted = 10
        let service = AdService(network: network, rules: AdRules(), ledger: ledger, adsRemoved: true)
        let shown = await service.roundDidEnd()
        XCTAssertFalse(shown)
        let earned = await service.showRewarded(placement: "hint")
        XCTAssertTrue(earned)
        XCTAssertFalse(service.bannerAllowed(onGameTable: false))
    }
}

@MainActor
final class ConfigServiceTests: XCTestCase {
    func testTypedValuesWithFallbacks() async {
        let source = DictionaryConfigSource(["a": "7", "b": "nope", "c": "0.5", "d": "false", "e": "maybe"])
        let config = ConfigService(source: source)
        XCTAssertEqual(config.value(ConfigKey("a", default: 1)), 7)
        XCTAssertEqual(config.value(ConfigKey("b", default: 3)), 3)
        XCTAssertEqual(config.value(ConfigKey("c", default: 1.0)), 0.5)
        XCTAssertEqual(config.value(ConfigKey("d", default: true)), false)
        XCTAssertEqual(config.value(ConfigKey("e", default: true)), true)
        XCTAssertEqual(config.value(ConfigKey("missing", default: "x")), "x")
        config.overrides["a"] = "9"
        XCTAssertEqual(config.value(ConfigKey("a", default: 1)), 9)
        config.update(source: DictionaryConfigSource())
        config.overrides = [:]
        XCTAssertEqual(config.value(ConfigKey("a", default: 1)), 1)
    }
}

@MainActor
final class SaveServiceTests: XCTestCase {
    struct Progress: Codable, Equatable, Sendable { var coins: Int; var revision: Int }

    func testLocalAndCloudMerge() async {
        let local = MemorySaveStore()
        let cloud = MemorySaveStore()
        let merge: (Progress, Progress) -> Progress = { $0.revision >= $1.revision ? $0 : $1 }
        let service = SaveService<Progress>(key: "p", local: local, cloud: cloud, merge: merge)
        XCTAssertNil(service.load())
        service.save(Progress(coins: 5, revision: 1))
        XCTAssertEqual(service.load(), Progress(coins: 5, revision: 1))

        // Another device wrote a newer save to iCloud.
        cloud.write(try! JSONEncoder().encode(Progress(coins: 50, revision: 4)), for: "p")
        XCTAssertEqual(service.load(), Progress(coins: 50, revision: 4))
        let adopted = service.mergeCloudChange(into: Progress(coins: 5, revision: 1))
        XCTAssertEqual(adopted.coins, 50)
        XCTAssertEqual(local.read("p").flatMap { try? JSONDecoder().decode(Progress.self, from: $0) }, adopted)

        service.reset()
        XCTAssertNil(service.load())
    }

    func testFileStoreRoundTrip() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileSaveStore(directory: dir)
        store.write(Data("hi".utf8), for: "k")
        XCTAssertEqual(store.read("k"), Data("hi".utf8))
        store.remove("k")
        XCTAssertNil(store.read("k"))
        try? FileManager.default.removeItem(at: dir)
    }

    func testCorruptSaveIsIgnored() async {
        let local = MemorySaveStore()
        local.write(Data("garbage".utf8), for: "p")
        let service = SaveService<Progress>(key: "p", local: local, merge: { a, _ in a })
        XCTAssertNil(service.load())
    }
}

@MainActor
final class PurchaseTests: XCTestCase {
    func testEntitlements() async {
        let now = Date()
        var entitlements = Entitlements()
        XCTAssertFalse(entitlements.adsRemoved(removeAdsID: "remove_ads", at: now))
        entitlements.ownedNonConsumables.insert("remove_ads")
        XCTAssertTrue(entitlements.adsRemoved(removeAdsID: "remove_ads", at: now))

        var club = Entitlements(activeSubscription: "club.monthly", subscriptionExpires: now.addingTimeInterval(60))
        XCTAssertTrue(club.isSubscriber(at: now))
        XCTAssertTrue(club.adsRemoved(removeAdsID: "remove_ads", at: now))
        XCTAssertFalse(club.isSubscriber(at: now.addingTimeInterval(120)))
        club.subscriptionExpires = nil
        XCTAssertTrue(club.isSubscriber(at: now))
    }

    func testFakePurchaseFlow() async {
        let catalog = [ProductDefinition(id: "remove_ads", kind: .removeAds),
                       ProductDefinition(id: "warmth_small", kind: .consumable, currencyAmount: 200),
                       ProductDefinition(id: "club.monthly", kind: .subscription)]
        let service = FakePurchaseService(catalog: catalog)
        var granted = 0
        service.onConsumable = { granted += $0.currencyAmount }
        let consumable = await service.purchase("warmth_small")
        XCTAssertEqual(consumable, .success(productID: "warmth_small"))
        XCTAssertEqual(granted, 200)
        _ = await service.purchase("remove_ads")
        XCTAssertTrue(service.entitlements.ownedNonConsumables.contains("remove_ads"))
        _ = await service.purchase("club.monthly")
        XCTAssertTrue(service.entitlements.isSubscriber())
        let unknown = await service.purchase("nope")
        XCTAssertEqual(unknown, .failed("unknown product"))
        XCTAssertEqual(service.products.count, 3)
    }

    func testFakeConsent() async {
        let consent = FakeConsentService()
        let state = await consent.gatherConsent()
        XCTAssertTrue(state.canRequestAds)
    }
}
