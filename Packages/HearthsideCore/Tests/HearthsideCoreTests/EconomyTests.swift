import XCTest
@testable import HearthsideCore

final class EconomyTests: XCTestCase {
    let catalog = VillageCatalog.season1

    func testCatalogMatchesPlan() {
        XCTAssertEqual(catalog.count, 8)
        XCTAssertEqual(catalog.map(\.id), ["bakery", "parsonage", "millhouse", "farmhouse",
                                           "schoolhouse", "lighthouse", "station", "manor"])
        for house in catalog {
            XCTAssertTrue((6...8).contains(house.measures.count), house.id)
            XCTAssertEqual(Set(house.measures.map(\.kind)).count, house.measures.count, "no duplicates in \(house.id)")
            XCTAssertGreaterThanOrEqual(house.maxLabel, .a, "every house reaches at least A")
            XCTAssertTrue(house.measures.allSatisfy { $0.cost > 0 })
            // Listed order already follows the smart (trias energetica) order.
            let phases = house.measures.map(\.kind.phase)
            XCTAssertEqual(phases, phases.sorted(), house.id)
        }
        // Later houses cost more.
        XCTAssertLessThan(catalog[0].totalCost, catalog[7].totalCost)
    }

    func testLabels() {
        XCTAssertEqual(EnergyLabel.g.raised(by: 6), .a)
        XCTAssertEqual(EnergyLabel.g.raised(by: 8), .aPlusPlus)
        XCTAssertEqual(EnergyLabel.a.raised(by: 10), .aPlusPlus)
        XCTAssertEqual(EnergyLabel.aPlus.title, "A+")
        XCTAssertEqual(EnergyLabel.g.warmth, 0)
        XCTAssertEqual(EnergyLabel.aPlusPlus.warmth, 1)
    }

    func testBuyingRaisesLabelAndSpendsWarmth() throws {
        var village = VillageState(warmth: 1_000)
        let bakery = catalog[0]
        let receipt = try village.buy(.draughtProofing, in: "bakery")
        XCTAssertEqual(receipt.labelBefore, .g)
        XCTAssertEqual(receipt.labelAfter, .f)
        XCTAssertTrue(receipt.smartOrder)
        let cost = bakery.measures[0].cost
        XCTAssertEqual(receipt.refund, Int((Double(cost) * 0.2).rounded()))
        XCTAssertEqual(village.warmth, 1_000 - cost + receipt.refund)
        XCTAssertThrowsError(try village.buy(.draughtProofing, in: "bakery")) {
            XCTAssertEqual($0 as? PurchaseError, .alreadyDone)
        }
    }

    func testHeatPumpBeforeInsulationGetsNoBonus() throws {
        var village = VillageState(warmth: 1_000)
        let receipt = try village.buy(.hybridHeatPump, in: "bakery")
        XCTAssertFalse(receipt.smartOrder)
        XCTAssertEqual(receipt.refund, 0)
        XCTAssertEqual(receipt.labelAfter, .f, "still raises the label one step")
    }

    func testNotEnoughWarmth() {
        var village = VillageState(warmth: 3)
        XCTAssertThrowsError(try village.buy(.draughtProofing, in: "bakery")) { error in
            guard case PurchaseError.notEnoughWarmth(let missing)? = error as? PurchaseError else {
                return XCTFail("wrong error \(error)")
            }
            XCTAssertEqual(missing, self.catalog[0].measures[0].cost - 3)
        }
    }

    func testHouseUnlocking() throws {
        var village = VillageState(warmth: 10_000)
        XCTAssertTrue(village.isUnlocked("bakery"))
        XCTAssertFalse(village.isUnlocked("parsonage"))
        XCTAssertThrowsError(try village.buy(.draughtProofing, in: "parsonage")) {
            XCTAssertEqual($0 as? PurchaseError, .houseLocked)
        }
        for measure in catalog[0].measures.prefix(4) { try village.buy(measure.kind, in: "bakery") }
        XCTAssertEqual(village.progress("bakery").label(for: catalog[0]), .c)
        XCTAssertTrue(village.isUnlocked("parsonage"))
        XCTAssertFalse(village.isUnlocked("nonexistent"))
    }

    func testCompletingAHouse() throws {
        var village = VillageState(warmth: 10_000)
        var last: PurchaseReceipt?
        for measure in catalog[0].measures { last = try village.buy(measure.kind, in: "bakery") }
        XCTAssertEqual(last?.houseCompleted, true)
        XCTAssertEqual(last?.labelAfter, .a)
        XCTAssertEqual(village.completedHouseCount, 1)
        XCTAssertTrue(village.progress("bakery").visuals(for: catalog[0]).contains(.solarPanels))
        XCTAssertGreaterThan(village.villageWarmth(), 0)
        XCTAssertEqual(village.nextGoal()?.house.id, "parsonage")
    }

    func testUnknownHouseOrMeasure() {
        var village = VillageState(warmth: 10_000)
        XCTAssertThrowsError(try village.buy(.tripleGlazing, in: "bakery"))
        XCTAssertThrowsError(try village.buy(.draughtProofing, in: "castle"))
    }

    func testWinRewardBonuses() throws {
        var game = KlondikeGame(deal: DealInfo(seed: 1, winnable: true, difficulty: .hard, dailyDate: "2026-11-14"),
                                rules: .standard(drawCount: 3))
        game.elapsed = 100
        let reward = WarmthEconomy.reward(for: game)
        XCTAssertEqual(reward.base, 20)
        XCTAssertEqual(reward.noHints, 5)
        XCTAssertEqual(reward.fast, 5)
        XCTAssertEqual(reward.efficient, 5)
        XCTAssertEqual(reward.difficulty, 5)
        XCTAssertEqual(reward.drawThree, 3)
        XCTAssertEqual(reward.daily, 15)
        XCTAssertEqual(reward.total, 58)
        XCTAssertEqual(WarmthEconomy.reward(for: game, isClubMember: true).total, 116)

        game.registerHint()
        game.elapsed = 1_000
        let plain = WarmthEconomy.reward(for: game)
        XCTAssertEqual(plain.noHints, 0)
        XCTAssertEqual(plain.fast, 0)
    }

    func testVillageEarnIgnoresNegative() {
        var village = VillageState()
        village.earn(-5)
        XCTAssertEqual(village.warmth, 0)
        village.earn(12)
        XCTAssertEqual(village.lifetimeWarmth, 12)
    }

    func testMeasureMetadata() {
        for kind in MeasureKind.allCases {
            XCTAssertTrue(kind.nameKey.hasPrefix("measure."))
            XCTAssertTrue(kind.tipKey.hasSuffix(".tip"))
            _ = kind.visual
        }
        XCTAssertEqual(MeasureKind.solarPanels.phase, .generation)
        XCTAssertEqual(MeasureKind.heatPump.phase, .installation)
        XCTAssertEqual(catalog[0].nameKey, "house.bakery.name")
    }
}
