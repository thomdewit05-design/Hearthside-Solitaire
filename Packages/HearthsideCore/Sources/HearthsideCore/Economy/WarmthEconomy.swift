import Foundation

/// Tunable numbers for the warmth economy. All values can be overridden from
/// Remote Config (keys in `GameConfigKeys`).
public struct EconomyConfig: Codable, Hashable, Sendable {
    public var baseWinReward: Int = 20
    public var noHintBonus: Int = 5
    public var fastWinBonus: Int = 5
    public var fastWinSeconds: Double = 240
    public var efficientWinBonus: Int = 5
    public var efficientWinMoves: Int = 110
    public var normalDifficultyBonus: Int = 2
    public var hardDifficultyBonus: Int = 5
    public var drawThreeBonus: Int = 3
    public var dailyChallengeBonus: Int = 15
    /// Fraction of the cost refunded when a measure is bought in the smart order.
    public var smartOrderRefund: Double = 0.2
    public var clubMultiplier: Int = 2

    public init() {}
}

public struct WinReward: Codable, Hashable, Sendable {
    public var base: Int
    public var noHints: Int
    public var fast: Int
    public var efficient: Int
    public var difficulty: Int
    public var drawThree: Int
    public var daily: Int
    public var multiplier: Int

    public var subtotal: Int { base + noHints + fast + efficient + difficulty + drawThree + daily }
    public var total: Int { subtotal * multiplier }
}

public enum WarmthEconomy {
    public static func reward(for game: KlondikeGame, config: EconomyConfig = .init(), isClubMember: Bool = false) -> WinReward {
        let difficultyBonus: Int
        switch game.deal.difficulty {
        case .hard?: difficultyBonus = config.hardDifficultyBonus
        case .normal?: difficultyBonus = config.normalDifficultyBonus
        default: difficultyBonus = 0
        }
        return WinReward(
            base: config.baseWinReward,
            noHints: game.hintsUsed == 0 ? config.noHintBonus : 0,
            fast: game.elapsed > 0 && game.elapsed <= config.fastWinSeconds ? config.fastWinBonus : 0,
            efficient: game.moveCount <= config.efficientWinMoves ? config.efficientWinBonus : 0,
            difficulty: difficultyBonus,
            drawThree: game.rules.drawCount == 3 ? config.drawThreeBonus : 0,
            daily: game.deal.dailyDate != nil ? config.dailyChallengeBonus : 0,
            multiplier: isClubMember ? config.clubMultiplier : 1)
    }
}

/// Progress on one house: which measures are done, in purchase order.
public struct HouseProgress: Codable, Hashable, Sendable {
    public var completed: [MeasureKind] = []

    public init(completed: [MeasureKind] = []) {
        self.completed = completed
    }

    public func label(for blueprint: HouseBlueprint) -> EnergyLabel {
        EnergyLabel.g.raised(by: completed.filter { kind in blueprint.measures.contains { $0.kind == kind } }.count)
    }

    public func isComplete(_ blueprint: HouseBlueprint) -> Bool {
        blueprint.measures.allSatisfy { completed.contains($0.kind) }
    }

    public func visuals(for blueprint: HouseBlueprint) -> Set<HouseVisual> {
        Set(completed.map(\.visual))
    }
}

public enum PurchaseError: Error, Equatable {
    case unknownHouse
    case houseLocked
    case alreadyDone
    case notEnoughWarmth(missing: Int)
}

public struct PurchaseReceipt: Codable, Hashable, Sendable {
    public var houseID: String
    public var measure: MeasureKind
    public var cost: Int
    public var refund: Int
    public var labelBefore: EnergyLabel
    public var labelAfter: EnergyLabel
    public var smartOrder: Bool
    public var houseCompleted: Bool
}

/// The village state: warmth wallet plus progress per house.
public struct VillageState: Codable, Hashable, Sendable {
    public var warmth: Int
    public var houses: [String: HouseProgress]
    public var lifetimeWarmth: Int

    public init(warmth: Int = 0, houses: [String: HouseProgress] = [:], lifetimeWarmth: Int = 0) {
        self.warmth = warmth
        self.houses = houses
        self.lifetimeWarmth = lifetimeWarmth
    }

    public func progress(_ houseID: String) -> HouseProgress { houses[houseID] ?? HouseProgress() }

    /// A house unlocks when the previous house in the catalog is at least label C.
    public func isUnlocked(_ houseID: String, catalog: [HouseBlueprint] = VillageCatalog.season1) -> Bool {
        guard let index = catalog.firstIndex(where: { $0.id == houseID }) else { return false }
        if index == 0 { return true }
        let previous = catalog[index - 1]
        return progress(previous.id).label(for: previous) >= .c
    }

    public var completedHouseCount: Int {
        VillageCatalog.season1.filter { progress($0.id).isComplete($0) }.count
    }

    /// 0…1 overall warmth of the village (for the colour grading of the scene).
    public func villageWarmth(catalog: [HouseBlueprint] = VillageCatalog.season1) -> Double {
        let done = catalog.reduce(0) { $0 + progress($1.id).completed.count }
        let total = catalog.reduce(0) { $0 + $1.measures.count }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    public mutating func earn(_ amount: Int) {
        guard amount > 0 else { return }
        warmth += amount
        lifetimeWarmth += amount
    }

    /// True when buying `kind` now follows the trias-energetica order:
    /// every measure of an earlier phase in this house is already done.
    public func isSmartOrder(_ kind: MeasureKind, in blueprint: HouseBlueprint) -> Bool {
        let done = progress(blueprint.id).completed
        return blueprint.measures
            .filter { $0.kind.phase < kind.phase }
            .allSatisfy { done.contains($0.kind) }
    }

    @discardableResult
    public mutating func buy(_ kind: MeasureKind, in houseID: String, config: EconomyConfig = .init(),
                             catalog: [HouseBlueprint] = VillageCatalog.season1) throws -> PurchaseReceipt {
        guard let blueprint = catalog.first(where: { $0.id == houseID }),
              let measure = blueprint.measures.first(where: { $0.kind == kind }) else { throw PurchaseError.unknownHouse }
        guard isUnlocked(houseID, catalog: catalog) else { throw PurchaseError.houseLocked }
        var house = progress(houseID)
        guard !house.completed.contains(kind) else { throw PurchaseError.alreadyDone }
        guard warmth >= measure.cost else { throw PurchaseError.notEnoughWarmth(missing: measure.cost - warmth) }

        let smart = isSmartOrder(kind, in: blueprint)
        let refund = smart ? Int((Double(measure.cost) * config.smartOrderRefund).rounded()) : 0
        let before = house.label(for: blueprint)
        warmth -= measure.cost
        warmth += refund
        house.completed.append(kind)
        houses[houseID] = house
        return PurchaseReceipt(houseID: houseID, measure: kind, cost: measure.cost, refund: refund,
                               labelBefore: before, labelAfter: house.label(for: blueprint),
                               smartOrder: smart, houseCompleted: house.isComplete(blueprint))
    }

    /// The cheapest measure the player can work towards next (for "next goal" UI).
    public func nextGoal(catalog: [HouseBlueprint] = VillageCatalog.season1) -> (house: HouseBlueprint, measure: Measure)? {
        for blueprint in catalog where isUnlocked(blueprint.id, catalog: catalog) {
            let done = progress(blueprint.id).completed
            let open = blueprint.measures.filter { !done.contains($0.kind) }
            if let smart = open.first(where: { isSmartOrder($0.kind, in: blueprint) }) ?? open.first {
                return (blueprint, smart)
            }
        }
        return nil
    }
}
