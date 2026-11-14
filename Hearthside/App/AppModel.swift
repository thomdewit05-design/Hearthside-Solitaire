import Foundation
import Observation
import SwiftUI
import GameServices
import HearthsideCore

/// Navigation destinations from the home screen.
enum Route: Hashable {
    case table
    case village
    case house(String)
    case daily
    case stats
    case shop
    case settings
    #if DEBUG
    case debug
    #endif
}

/// Natural-moment offers (never at launch).
enum ShopOffer: String, Identifiable {
    case starterPack, lowWarmth
    var id: String { rawValue }
}

/// The app's single source of truth: player progress, settings, services and the active game.
@MainActor
@Observable
final class AppModel {
    // MARK: State
    private(set) var progress: PlayerProgress
    private(set) var settings: UserSettings
    private(set) var entitlements = Entitlements()
    var path: [Route] = []
    private(set) var activeGame: GameController? = nil
    var pendingOffer: ShopOffer? = nil

    // MARK: Services
    let config: ConfigService
    let analytics: AnalyticsService
    let ads: AdService
    let purchases: PurchaseServicing
    let consent: ConsentServicing
    let gameCenter = GameCenterService()
    let sound = SoundService()
    let haptics = HapticsService()
    private let progressStore: SaveService<PlayerProgress>
    private let settingsStore: SaveService<UserSettings>
    private let gameStore: SaveService<KlondikeGame>
    private let ledgerStore: SaveService<AdLedger>
    private let libraries: [Int: DealLibrary]
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()

    var today: DayKey { DayKey(date: Date()) }
    var isClubMember: Bool { entitlements.isSubscriber() }
    var adsRemoved: Bool { entitlements.adsRemoved(removeAdsID: ProductIDs.removeAds) }

    init(local: SaveStore = FileSaveStore(), cloud: SaveStore? = AppModel.defaultCloudStore()) {
        let progressStore = SaveService<PlayerProgress>(key: "progress", local: local, cloud: cloud,
                                                        merge: PlayerProgress.merged)
        let settingsStore = SaveService<UserSettings>(key: "settings", local: local, merge: { mine, _ in mine })
        let gameStore = SaveService<KlondikeGame>(key: "current-game", local: local, merge: { mine, _ in mine })
        let ledgerStore = SaveService<AdLedger>(key: "ad-ledger", local: local, merge: { mine, _ in mine })
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.gameStore = gameStore
        self.ledgerStore = ledgerStore

        let loadedSettings = settingsStore.load() ?? UserSettings()
        progress = progressStore.load() ?? PlayerProgress()
        settings = loadedSettings
        libraries = DealLibraryLoader.loadAll()

        let analytics = AnalyticsService()
        let config = ConfigService()
        #if canImport(FirebaseAnalytics)
        analytics.add(FirebaseAnalyticsSink())
        #endif
        self.analytics = analytics
        self.config = config

        #if canImport(GoogleMobileAds) && canImport(UIKit)
        let network: AdNetwork = GoogleAdNetwork(units: AdUnits.current)
        #else
        let network: AdNetwork = FakeAdNetwork()
        #endif
        ads = AdService(network: network,
                        rules: AppModel.adRules(config),
                        ledger: ledgerStore.load() ?? AdLedger(),
                        analytics: analytics,
                        persist: { ledgerStore.save($0) })

        // In the simulator, StoreKit uses Hearthside.storekit (set in the scheme).
        purchases = StoreKitPurchaseService(catalog: ProductIDs.catalog)

        #if canImport(UserMessagingPlatform) && canImport(UIKit)
        consent = UMPConsentService()
        #else
        consent = FakeConsentService()
        #endif

        sound.isEnabled = loadedSettings.soundEnabled
        haptics.isEnabled = loadedSettings.hapticsEnabled
        if let saved = gameStore.load(), !saved.isWon {
            activeGame = GameController(game: saved, app: self)
        }
    }

    nonisolated static func defaultCloudStore() -> SaveStore? {
        FileManager.default.ubiquityIdentityToken == nil ? nil : UbiquitousSaveStore()
    }

    static func adRules(_ config: ConfigService) -> AdRules {
        AdRules(interstitialFirstRound: config.value(ConfigKeys.interstitialFirstRound),
                interstitialMinInterval: config.value(ConfigKeys.interstitialMinInterval),
                cooldownAfterRewarded: config.value(ConfigKeys.cooldownAfterRewarded),
                rewardedDailyCap: config.value(ConfigKeys.rewardedDailyCap),
                interstitialsEnabled: config.value(ConfigKeys.interstitialsEnabled),
                bannersEnabled: config.value(ConfigKeys.bannersEnabled))
    }

    var economyConfig: EconomyConfig {
        var economy = EconomyConfig()
        economy.baseWinReward = config.value(ConfigKeys.baseWinReward)
        economy.smartOrderRefund = config.value(ConfigKeys.smartOrderRefund)
        return economy
    }

    // MARK: - Launch

    /// Order matters: Remote Config → consent (UMP + ATT) → ads → purchases → Game Center.
    func start() async {
        #if canImport(FirebaseRemoteConfig)
        let remote = FirebaseConfigSource()
        await remote.fetchAndActivate()
        config.update(source: remote)
        ads.policy = AdPolicy(rules: AppModel.adRules(config))
        #endif
        purchases.onEntitlementsChanged = { [weak self] entitlements in
            self?.apply(entitlements)
        }
        purchases.onConsumable = { [weak self] product in
            self?.grantWarmth(product.currencyAmount, source: product.id)
        }
        await purchases.start()
        apply(purchases.entitlements)

        let consentState = await consent.gatherConsent()
        if consentState.canRequestAds { await ads.start() }
        gameCenter.authenticate()

        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let model = self else { return }
            Task { @MainActor in model.mergeCloud() }
        }
        analytics.log("app_open", ["games_played": String(progress.totalGamesPlayed)])
    }

    private func apply(_ entitlements: Entitlements) {
        self.entitlements = entitlements
        ads.adsRemoved = adsRemoved
        analytics.setUserProperty(isClubMember ? "club" : (adsRemoved ? "remove_ads" : "free"), for: "tier")
    }

    private func mergeCloud() {
        progress = progressStore.mergeCloudChange(into: progress)
    }

    // MARK: - Persistence

    func saveProgress() {
        progress.revision += 1
        progressStore.save(progress)
    }

    func updateSettings(_ change: (inout UserSettings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        settings = next
        settingsStore.save(settings)
        sound.isEnabled = settings.soundEnabled
        haptics.isEnabled = settings.hapticsEnabled
    }

    /// Two-way binding for SwiftUI controls in Settings.
    func setting<Value>(_ keyPath: WritableKeyPath<UserSettings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { value in self.updateSettings { $0[keyPath: keyPath] = value } })
    }

    func saveActiveGame() {
        guard let game = activeGame?.game else { return }
        if game.isWon { gameStore.reset() } else { gameStore.save(game) }
    }

    // MARK: - Dealing

    func library(drawCount: Int) -> DealLibrary {
        libraries[drawCount] ?? DealLibrary(drawCount: drawCount)
    }

    /// Continues the saved game, or deals a new one.
    func playClassic() {
        if activeGame == nil || activeGame?.game.deal.dailyDate != nil { newGame() }
        path.append(.table)
    }

    func newGame() {
        endActiveGameIfStarted()
        let rules = settings.rules
        let picker = DealPicker(library: library(drawCount: rules.drawCount),
                                newPlayerEasyGames: config.value(ConfigKeys.newPlayerEasyGames),
                                hardShare: config.value(ConfigKeys.hardDealShare))
        let deal = picker.nextDeal(gamesPlayed: progress.totalGamesPlayed,
                                   alwaysWinnable: settings.alwaysWinnable,
                                   recentSeeds: Set(progress.recentSeeds),
                                   using: &rng)
        start(KlondikeGame(deal: deal, rules: rules))
    }

    func replaySameDeal() {
        guard let current = activeGame?.game else { return }
        endActiveGameIfStarted()
        start(KlondikeGame(deal: current.deal, rules: current.rules))
    }

    func playDaily(_ day: DayKey) {
        endActiveGameIfStarted()
        // The daily challenge is always draw-1 standard so the leaderboard is fair.
        let deal = DailyChallengeState.deal(for: day, library: library(drawCount: 1))
        start(KlondikeGame(deal: deal, rules: .standard(drawCount: 1)))
        if path.last != .table { path.append(.table) }
    }

    private func start(_ game: KlondikeGame) {
        activeGame = GameController(game: game, app: self)
        saveActiveGame()
        analytics.log("deal_start", [
            "mode": "draw\(game.rules.drawCount)_\(game.rules.scoring.rawValue)",
            "winnable": game.deal.winnable ? "yes" : "no",
            "difficulty": game.deal.difficulty?.rawValue ?? "random",
            "daily": game.deal.dailyDate == nil ? "no" : "yes"
        ])
        sound.play(.shuffle)
    }

    /// An abandoned game that had moves counts as a loss and ends the round.
    private func endActiveGameIfStarted() {
        guard let game = activeGame?.game, game.hasStarted, !game.isWon else { return }
        progress.recordLoss(game)
        saveProgress()
        analytics.log("deal_abandoned", ["moves": String(game.moveCount), "time": String(Int(game.elapsed))])
        Task { await ads.roundDidEnd() }
    }

    // MARK: - Round end

    func didWin(_ game: KlondikeGame) -> WinSummary {
        let summary = progress.recordWin(game, config: economyConfig, isClubMember: isClubMember)
        saveProgress()
        saveActiveGame()
        analytics.log("deal_won", [
            "moves": String(game.moveCount),
            "time": String(Int(game.elapsed)),
            "hints": String(game.hintsUsed),
            "warmth": String(summary.warmthEarned)
        ])
        if let day = summary.dailyCompleted {
            analytics.log("daily_challenge_done", ["date": day.description])
            gameCenter.submitDailyTime(game.elapsed)
        }
        if progress.totalGamesWon == 1 { gameCenter.unlock(GameCenterIDs.firstWin) }
        if summary.winStreak >= 7 { gameCenter.unlock(GameCenterIDs.streak7) }
        if summary.monthDecoration != nil { gameCenter.unlock(GameCenterIDs.fullMonth) }
        return summary
    }

    /// Called from the win sheet's "Next game" button: between rounds, so an interstitial may show.
    func continueAfterWin() async {
        await ads.roundDidEnd()
        newGame()
    }

    func doubleWarmth(_ summary: WinSummary) async -> Bool {
        guard await ads.showRewarded(placement: "double_warmth") else { return false }
        _ = progress.grantDoubleWarmth(for: summary)
        saveProgress()
        return true
    }

    // MARK: - Village

    @discardableResult
    func buy(_ kind: MeasureKind, in houseID: String) -> Result<PurchaseReceipt, PurchaseError> {
        do {
            let receipt = try progress.village.buy(kind, in: houseID, config: economyConfig)
            saveProgress()
            sound.play(.warmth)
            haptics.success()
            analytics.log("upgrade_bought", [
                "house": houseID, "measure": kind.rawValue,
                "label_before": receipt.labelBefore.title, "label_after": receipt.labelAfter.title,
                "smart_order": receipt.smartOrder ? "yes" : "no"
            ])
            if receipt.labelAfter >= .a { gameCenter.unlock(GameCenterIDs.labelA) }
            if receipt.houseCompleted {
                analytics.log("house_completed", ["house": houseID])
                gameCenter.unlock(GameCenterIDs.firstHouse)
                if progress.village.completedHouseCount == VillageCatalog.season1.count {
                    gameCenter.unlock(GameCenterIDs.wholeVillage)
                }
                if config.value(ConfigKeys.offersEnabled) && progress.village.completedHouseCount == 1 {
                    pendingOffer = .starterPack
                }
            }
            return .success(receipt)
        } catch let error as PurchaseError {
            if case .notEnoughWarmth = error, config.value(ConfigKeys.offersEnabled), !isClubMember {
                pendingOffer = .lowWarmth
            }
            return .failure(error)
        } catch {
            return .failure(.unknownHouse)
        }
    }

    func grantWarmth(_ amount: Int, source: String) {
        progress.village.earn(amount)
        saveProgress()
        analytics.log("warmth_granted", ["amount": String(amount), "source": source])
    }

    // MARK: - Daily reward

    var canClaimDailyReward: Bool { progress.dailyReward.canClaim(today: today) }

    func claimDailyReward(doubled: Bool) async {
        if doubled {
            guard await ads.showRewarded(placement: "daily_reward_x2") else { return }
        }
        let amount = progress.dailyReward.claim(today: today) * (doubled ? 2 : 1)
        progress.village.earn(amount)
        saveProgress()
        analytics.log("daily_reward_claimed", ["amount": String(amount), "day": String(progress.dailyReward.streakDay)])
    }

    /// Catching up a missed day in the calendar costs one rewarded ad.
    func catchUpDaily(_ day: DayKey) async {
        guard await ads.showRewarded(placement: "daily_catch_up") else { return }
        playDaily(day)
    }

    // MARK: - Cosmetics

    func select(_ item: CosmeticItem) {
        progress.cosmetics.selected[item.category] = item.id
        saveProgress()
    }

    func unlockWithWarmth(_ item: CosmeticItem) -> Bool {
        guard case .warmth(let cost) = item.unlock, progress.village.warmth >= cost else { return false }
        progress.village.warmth -= cost
        progress.cosmetics.owned.insert(item.id)
        progress.cosmetics.selected[item.category] = item.id
        saveProgress()
        analytics.log("cosmetic_unlocked", ["item": item.id])
        return true
    }

    #if DEBUG
    func debugReset() {
        progress = PlayerProgress()
        saveProgress()
        activeGame = nil
        gameStore.reset()
    }
    #endif
}
