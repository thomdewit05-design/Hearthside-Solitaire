import Foundation

/// Daily challenge: one fixed, winnable deal per calendar day for everyone.
/// Completing every day of a month earns a special village decoration.
public struct DailyChallengeState: Codable, Hashable, Sendable {
    public var completed: Set<DayKey> = []
    /// Months ("2026-11") whose decoration has been awarded.
    public var awardedMonths: Set<String> = []

    public init() {}

    public func isCompleted(_ day: DayKey) -> Bool { completed.contains(day) }

    /// A day can be played if it is today, or a past day of the current month
    /// (catching up a missed day is offered via a rewarded ad).
    public func isPlayable(_ day: DayKey, today: DayKey) -> Bool {
        day <= today && day.monthKey == today.monthKey
    }

    public func needsCatchUp(_ day: DayKey, today: DayKey) -> Bool {
        isPlayable(day, today: today) && day < today && !isCompleted(day)
    }

    public func completedCount(inMonthOf day: DayKey) -> Int {
        completed.filter { $0.monthKey == day.monthKey }.count
    }

    public func isMonthComplete(_ day: DayKey) -> Bool {
        completedCount(inMonthOf: day) >= day.daysInMonth
    }

    /// Marks the day done. Returns the month key when this completes the month for the first time.
    @discardableResult
    public mutating func complete(_ day: DayKey) -> String? {
        completed.insert(day)
        if isMonthComplete(day) && !awardedMonths.contains(day.monthKey) {
            awardedMonths.insert(day.monthKey)
            return day.monthKey
        }
        return nil
    }

    /// Deterministic deal for a day, drawn from the normal pool so everyone gets the same game.
    public static func deal(for day: DayKey, library: DealLibrary) -> DealInfo {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(day.description.utf8) + Array("hearthside-daily".utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        let pool = library.normal.isEmpty ? (library.easy + library.hard) : library.normal
        guard !pool.isEmpty else {
            return DealInfo(seed: hash & 0x000F_FFFF_FFFF_FFFF, winnable: false, dailyDate: day.description)
        }
        let seed = pool[Int(hash % UInt64(pool.count))]
        return DealInfo(seed: seed, winnable: true, difficulty: .normal, dailyDate: day.description)
    }
}

/// Monthly decorations awarded for a full daily-challenge calendar.
public enum Decoration: String, Codable, Sendable, CaseIterable {
    case lanternPost, flowerBox, birdHouse, snowman, appleTree, bench, wellPump, christmasTree,
         pumpkinPatch, kite, beehive, windmillModel

    /// Month 1…12 → decoration.
    public static func forMonth(_ monthKey: String) -> Decoration {
        let month = Int(monthKey.split(separator: "-").last ?? "1") ?? 1
        let order: [Decoration] = [.snowman, .birdHouse, .flowerBox, .beehive, .appleTree, .kite,
                                   .bench, .wellPump, .windmillModel, .pumpkinPatch, .lanternPost, .christmasTree]
        return order[(month - 1 + 12) % 12]
    }

    public var nameKey: String { "decoration.\(rawValue)" }
}
