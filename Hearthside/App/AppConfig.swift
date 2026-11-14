import Foundation
import GameServices
import HearthsideCore

/// Remote Config keys with their v1 defaults (see docs/PLAN.md → Monetisatie).
enum ConfigKeys {
    static let interstitialFirstRound = ConfigKey("ads_interstitial_first_round", default: 4)
    static let interstitialMinInterval = ConfigKey("ads_interstitial_min_interval_s", default: 180.0)
    static let cooldownAfterRewarded = ConfigKey("ads_cooldown_after_rewarded_s", default: 120.0)
    static let rewardedDailyCap = ConfigKey("ads_rewarded_daily_cap", default: 15)
    static let interstitialsEnabled = ConfigKey("ads_interstitials_enabled", default: true)
    static let bannersEnabled = ConfigKey("ads_banners_enabled", default: true)

    static let newPlayerEasyGames = ConfigKey("deals_new_player_easy_games", default: 5)
    static let hardDealShare = ConfigKey("deals_hard_share", default: 0.35)
    static let freeHintsPerGame = ConfigKey("hints_free_per_game", default: 3)

    static let baseWinReward = ConfigKey("economy_base_win_reward", default: 20)
    static let smartOrderRefund = ConfigKey("economy_smart_order_refund", default: 0.2)
    static let offersEnabled = ConfigKey("shop_offers_enabled", default: true)
}

/// App Store product identifiers (also in Hearthside.storekit for local testing).
enum ProductIDs {
    static let removeAds = "com.hearthside.removeads"
    static let clubMonthly = "com.hearthside.club.monthly"
    static let clubYearly = "com.hearthside.club.yearly"
    static let warmthSmall = "com.hearthside.warmth.small"
    static let warmthMedium = "com.hearthside.warmth.medium"
    static let warmthLarge = "com.hearthside.warmth.large"
    static let starterPack = "com.hearthside.starterpack"

    static let catalog: [ProductDefinition] = [
        ProductDefinition(id: removeAds, kind: .removeAds),
        ProductDefinition(id: clubMonthly, kind: .subscription),
        ProductDefinition(id: clubYearly, kind: .subscription),
        ProductDefinition(id: warmthSmall, kind: .consumable, currencyAmount: 250),
        ProductDefinition(id: warmthMedium, kind: .consumable, currencyAmount: 700),
        ProductDefinition(id: warmthLarge, kind: .consumable, currencyAmount: 1_600),
        ProductDefinition(id: starterPack, kind: .consumable, currencyAmount: 500)
    ]
}

/// Ad unit IDs. Replace the production IDs before release; Debug always uses Google's test IDs.
enum AdUnits {
    static var current: AdUnitIDs {
        #if DEBUG
        return .googleTest
        #else
        return AdUnitIDs(interstitial: "ca-app-pub-XXXXXXXXXXXXXXXX/INTERSTITIAL",
                         rewarded: "ca-app-pub-XXXXXXXXXXXXXXXX/REWARDED",
                         banner: "ca-app-pub-XXXXXXXXXXXXXXXX/BANNER")
        #endif
    }
}

enum GameCenterIDs {
    static let dailyLeaderboard = "hearthside.daily.time"
    static let firstWin = "hearthside.achievement.first_win"
    static let firstHouse = "hearthside.achievement.first_house"
    static let labelA = "hearthside.achievement.label_a"
    static let streak7 = "hearthside.achievement.streak_7"
    static let fullMonth = "hearthside.achievement.daily_month"
    static let wholeVillage = "hearthside.achievement.village"
}

enum Links {
    static let privacy = URL(string: "https://hearthsidegame.com/privacy")!
    static let terms = URL(string: "https://hearthsidegame.com/terms")!
    static let support = URL(string: "mailto:support@hearthsidegame.com")!
}
