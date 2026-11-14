import Foundation

/// 7-day login reward. Missing a day restarts the streak at day 1.
public struct DailyRewardState: Codable, Hashable, Sendable {
    public static let rewards = [10, 15, 20, 25, 30, 40, 60]

    public var lastClaimed: DayKey?
    /// 1…7: the day of the streak that was last claimed.
    public var streakDay: Int = 0

    public init() {}

    public func canClaim(today: DayKey) -> Bool {
        guard let last = lastClaimed else { return true }
        return last < today
    }

    /// The streak day that would be claimed today (1…7).
    public func nextStreakDay(today: DayKey) -> Int {
        guard let last = lastClaimed, last.days(until: today) == 1 else { return 1 }
        return streakDay % 7 + 1
    }

    public func rewardForToday(_ today: DayKey) -> Int {
        Self.rewards[nextStreakDay(today: today) - 1]
    }

    /// Claims today's reward and returns the warmth earned (0 if already claimed).
    public mutating func claim(today: DayKey) -> Int {
        guard canClaim(today: today) else { return 0 }
        let day = nextStreakDay(today: today)
        streakDay = day
        lastClaimed = today
        return Self.rewards[day - 1]
    }
}

/// Lifetime statistics, split per draw mode.
public struct GameStatistics: Codable, Hashable, Sendable {
    public var gamesPlayed = 0
    public var gamesWon = 0
    public var currentWinStreak = 0
    public var longestWinStreak = 0
    public var bestTime: TimeInterval?
    public var fewestMoves: Int?
    public var bestScore: Int?
    public var totalTime: TimeInterval = 0

    public init() {}

    public var winRate: Double { gamesPlayed == 0 ? 0 : Double(gamesWon) / Double(gamesPlayed) }

    public mutating func recordWin(time: TimeInterval, moves: Int, score: Int) {
        gamesPlayed += 1
        gamesWon += 1
        currentWinStreak += 1
        longestWinStreak = max(longestWinStreak, currentWinStreak)
        bestTime = min(bestTime ?? .infinity, time)
        fewestMoves = min(fewestMoves ?? .max, moves)
        bestScore = max(bestScore ?? .min, score)
        totalTime += time
    }

    public mutating func recordLoss(time: TimeInterval) {
        gamesPlayed += 1
        currentWinStreak = 0
        totalTime += time
    }
}

/// Cosmetic items: card backs, tables and fireplaces.
public enum CosmeticCategory: String, Codable, Sendable, CaseIterable {
    case cardBack, table, fire
}

public struct CosmeticItem: Codable, Hashable, Sendable, Identifiable {
    public enum Unlock: Codable, Hashable, Sendable {
        case free
        case warmth(Int)
        case club
        case purchase(productID: String)
    }

    public var id: String
    public var category: CosmeticCategory
    public var unlock: Unlock
    public var nameKey: String { "cosmetic.\(id)" }
}

public enum CosmeticCatalog {
    public static let all: [CosmeticItem] = [
        CosmeticItem(id: "back_hearth", category: .cardBack, unlock: .free),
        CosmeticItem(id: "back_pine", category: .cardBack, unlock: .warmth(150)),
        CosmeticItem(id: "back_knit", category: .cardBack, unlock: .warmth(300)),
        CosmeticItem(id: "back_starry", category: .cardBack, unlock: .club),
        CosmeticItem(id: "table_oak", category: .table, unlock: .free),
        CosmeticItem(id: "table_walnut", category: .table, unlock: .warmth(250)),
        CosmeticItem(id: "table_quilt", category: .table, unlock: .warmth(400)),
        CosmeticItem(id: "table_slate", category: .table, unlock: .club),
        CosmeticItem(id: "fire_classic", category: .fire, unlock: .free),
        CosmeticItem(id: "fire_birch", category: .fire, unlock: .warmth(200)),
        CosmeticItem(id: "fire_lantern", category: .fire, unlock: .club)
    ]

    public static func defaultItem(_ category: CosmeticCategory) -> String {
        all.first { $0.category == category && $0.unlock == .free }!.id
    }
}

public struct CosmeticsState: Codable, Hashable, Sendable {
    public var owned: Set<String> = Set(CosmeticCatalog.all.filter { $0.unlock == .free }.map(\.id))
    public var selected: [CosmeticCategory: String] = [
        .cardBack: CosmeticCatalog.defaultItem(.cardBack),
        .table: CosmeticCatalog.defaultItem(.table),
        .fire: CosmeticCatalog.defaultItem(.fire)
    ]

    public init() {}

    public func isAvailable(_ item: CosmeticItem, isClubMember: Bool) -> Bool {
        owned.contains(item.id) || (item.unlock == .club && isClubMember)
    }
}

/// Everything about the player that is saved locally and synced through iCloud.
public struct PlayerProgress: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version = PlayerProgress.currentVersion
    public var village = VillageState()
    public var daily = DailyChallengeState()
    public var dailyReward = DailyRewardState()
    public var statsDrawOne = GameStatistics()
    public var statsDrawThree = GameStatistics()
    public var cosmetics = CosmeticsState()
    public var decorations: [Decoration] = []
    public var recentSeeds: [UInt64] = []
    /// Bumped on every change; used to resolve iCloud conflicts (highest wins, then merge).
    public var revision = 0

    public init() {}

    public var totalGamesPlayed: Int { statsDrawOne.gamesPlayed + statsDrawThree.gamesPlayed }
    public var totalGamesWon: Int { statsDrawOne.gamesWon + statsDrawThree.gamesWon }

    public mutating func rememberSeed(_ seed: UInt64) {
        recentSeeds.append(seed)
        if recentSeeds.count > 200 { recentSeeds.removeFirst(recentSeeds.count - 200) }
    }

    /// Combines two saves (e.g. local and iCloud) without losing progress on either device.
    public static func merged(_ a: PlayerProgress, _ b: PlayerProgress) -> PlayerProgress {
        var base = a.revision >= b.revision ? a : b
        let other = a.revision >= b.revision ? b : a
        // Never lose purchased measures.
        for (id, house) in other.village.houses {
            var mine = base.village.progress(id)
            for kind in house.completed where !mine.completed.contains(kind) { mine.completed.append(kind) }
            base.village.houses[id] = mine
        }
        base.village.lifetimeWarmth = max(base.village.lifetimeWarmth, other.village.lifetimeWarmth)
        base.daily.completed.formUnion(other.daily.completed)
        base.daily.awardedMonths.formUnion(other.daily.awardedMonths)
        base.cosmetics.owned.formUnion(other.cosmetics.owned)
        for decoration in other.decorations where !base.decorations.contains(decoration) {
            base.decorations.append(decoration)
        }
        base.revision = max(a.revision, b.revision) + 1
        return base
    }
}
