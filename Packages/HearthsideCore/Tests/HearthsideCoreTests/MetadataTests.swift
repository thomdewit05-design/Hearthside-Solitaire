import XCTest
@testable import HearthsideCore

final class MetadataTests: XCTestCase {
    func testMoveDescriptionsAndTargets() {
        let moves: [Move] = [.draw, .wasteToFoundation, .wasteToTableau(2), .tableauToFoundation(1),
                             .tableauToTableau(from: 0, count: 2, to: 3), .foundationToTableau(.hearts, 4)]
        XCTAssertEqual(moves.map(\.description), ["draw", "W→F", "W→T2", "T1→F", "T0→T3×2", "F♥→T4"])
        XCTAssertEqual(moves.map(\.target), [nil, nil, .tableau(2), nil, .tableau(3), .tableau(4)])
        XCTAssertEqual(moves.map(\.isFoundationMove), [false, true, false, true, false, false])
    }

    func testEnergyLabelPresentation() {
        XCTAssertEqual(EnergyLabel.allCases.map(\.title), ["G", "F", "E", "D", "C", "B", "A", "A+", "A++"])
        XCTAssertEqual(Set(EnergyLabel.allCases.map(\.colorHex)).count, EnergyLabel.allCases.count)
        XCTAssertLessThan(EnergyLabel.g, EnergyLabel.a)
    }

    func testRulesFactory() {
        XCTAssertEqual(KlondikeRules.make(drawCount: 3, scoring: .vegas), .vegas(drawCount: 3))
        XCTAssertEqual(KlondikeRules.make(drawCount: 1, scoring: .standard), .standard(drawCount: 1))
        XCTAssertNil(KlondikeRules.standard().maxRecycles)
        XCTAssertEqual(KlondikeRules.vegas().maxRecycles, 0)
    }

    func testCardPresentation() {
        XCTAssertEqual(Suit.allCases.map(\.symbol), ["♠", "♥", "♣", "♦"])
        XCTAssertEqual(Suit.allCases.map(\.isRed), [false, true, false, true])
        XCTAssertEqual(Card(rank: 11, suit: .clubs).rankLabel, "J")
        XCTAssertEqual(Card(rank: 13, suit: .clubs).rankNameKey, "rank.king")
        XCTAssertEqual(Card(rank: 1, suit: .clubs).rankNameKey, "rank.ace")
        XCTAssertEqual(Card(rank: 11, suit: .clubs).rankNameKey, "rank.jack")
        XCTAssertEqual(Card(raw: 0), Card(rank: 1, suit: .spades))
        XCTAssertLessThan(Card(raw: 1), Card(raw: 2))
        XCTAssertEqual(Suit.spades.nameKey, "suit.spades")
        XCTAssertEqual(Suit.clubs.nameKey, "suit.clubs")
        XCTAssertEqual(Suit.diamonds.nameKey, "suit.diamonds")
    }

    func testDayKeyHelpers() {
        let day = DayKey(year: 2026, month: 11, day: 14)
        XCTAssertEqual(day.firstOfMonth, DayKey(year: 2026, month: 11, day: 1))
        XCTAssertEqual(day.monthKey, "2026-11")
        XCTAssertEqual(DayKey(date: day.date, calendar: Calendar(identifier: .gregorian)).monthKey, "2026-11")
        XCTAssertThrowsError(try JSONDecoder().decode([DayKey].self, from: Data("[\"x\"]".utf8)))
        XCTAssertEqual(DayKey(year: 2026, month: 11, day: 16).isoWeekday, 1, "Monday")
        XCTAssertEqual(DayKey(year: 2026, month: 11, day: 15).isoWeekday, 7, "Sunday")
    }

    func testDecorationsCoverAllMonths() {
        let months = (1...12).map { Decoration.forMonth(String(format: "2026-%02d", $0)) }
        XCTAssertEqual(Set(months).count, 12)
        XCTAssertEqual(Decoration.snowman.nameKey, "decoration.snowman")
    }

    func testFoundationToTableauTapAndDailyCatchUp() throws {
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 3, suit: .spades)], faceDownCount: 0)
        let state = KlondikeState(stock: [], waste: [], foundations: [0, 2, 0, 0], tableau: tableau)
        let game = KlondikeGame(state: state, rules: .standard(), deal: DealInfo(seed: 0, winnable: false))
        XCTAssertEqual(game.bestMove(forTapAt: .foundation(.hearts)), .foundationToTableau(.hearts, 0))
        XCTAssertNil(game.bestMove(forTapAt: .waste))
        XCTAssertNil(game.bestMove(forTapAt: .stock))
        XCTAssertNil(game.bestMove(forTapAt: .tableau(column: 9, index: 0)))
        XCTAssertEqual(game.move(from: .foundation(.hearts), to: .tableau(0)), .foundationToTableau(.hearts, 0))
        XCTAssertNil(game.move(from: .stock, to: .tableau(0)))
    }
}
