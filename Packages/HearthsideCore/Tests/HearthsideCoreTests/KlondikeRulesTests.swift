import XCTest
@testable import HearthsideCore

final class CardTests: XCTestCase {
    func testPackingRoundTrips() {
        for suit in Suit.allCases {
            for rank in 1...13 {
                let card = Card(rank: rank, suit: suit)
                XCTAssertEqual(card.rank, rank)
                XCTAssertEqual(card.suit, suit)
            }
        }
        XCTAssertEqual(Card.fullDeck.count, 52)
        XCTAssertEqual(Set(Card.fullDeck).count, 52)
    }

    func testStacking() {
        let redSeven = Card(rank: 7, suit: .hearts)
        XCTAssertTrue(redSeven.canStack(on: Card(rank: 8, suit: .spades)))
        XCTAssertFalse(redSeven.canStack(on: Card(rank: 8, suit: .diamonds)))
        XCTAssertFalse(redSeven.canStack(on: Card(rank: 9, suit: .clubs)))
    }

    func testLabels() {
        XCTAssertEqual(Card(rank: 1, suit: .spades).description, "A♠")
        XCTAssertEqual(Card(rank: 12, suit: .hearts).rankNameKey, "rank.queen")
        XCTAssertEqual(Card(rank: 7, suit: .hearts).rankNameKey, "rank.7")
        XCTAssertEqual(Suit.hearts.nameKey, "suit.hearts")
    }

    func testCodable() throws {
        let card = Card(rank: 11, suit: .diamonds)
        let data = try JSONEncoder().encode([card])
        XCTAssertEqual(try JSONDecoder().decode([Card].self, from: data), [card])
        XCTAssertThrowsError(try JSONDecoder().decode([Card].self, from: Data("[60]".utf8)))
    }

    func testShuffleIsDeterministicAndComplete() {
        let a = [Card].shuffledDeck(seed: 42)
        let b = [Card].shuffledDeck(seed: 42)
        let c = [Card].shuffledDeck(seed: 43)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(Set(a).count, 52)
    }

    func testRandomBelowStaysInRange() {
        var rng = SeededRandom(seed: 7)
        for _ in 0..<1_000 { XCTAssertTrue((0..<5).contains(rng.next(below: 5))) }
    }
}

final class KlondikeStateTests: XCTestCase {
    let rules = KlondikeRules.standard(drawCount: 1)

    func testDealLayout() {
        let state = KlondikeState.deal(seed: 1)
        XCTAssertEqual(state.stock.count, 24)
        XCTAssertTrue(state.waste.isEmpty)
        for (index, column) in state.tableau.enumerated() {
            XCTAssertEqual(column.cards.count, index + 1)
            XCTAssertEqual(column.faceDownCount, index)
        }
        let all = state.stock + state.tableau.flatMap(\.cards)
        XCTAssertEqual(Set(all).count, 52)
    }

    func testDrawOneAndRecycle() throws {
        var state = KlondikeState.deal(seed: 3)
        let firstTop = state.stock.last
        try state.apply(.draw, rules: rules)
        XCTAssertEqual(state.waste.last, firstTop)
        XCTAssertEqual(state.stock.count, 23)
        for _ in 0..<23 { try state.apply(.draw, rules: rules) }
        XCTAssertTrue(state.stock.isEmpty)
        let outcome = try state.apply(.draw, rules: rules)
        XCTAssertTrue(outcome.recycled)
        XCTAssertEqual(state.stock.count, 24)
        XCTAssertEqual(state.stock.last, firstTop, "recycling restores the original order")
        XCTAssertEqual(state.recycles, 1)
    }

    func testDrawThree() throws {
        let rules3 = KlondikeRules.standard(drawCount: 3)
        var state = KlondikeState.deal(seed: 3)
        let expectedTop = state.stock[state.stock.count - 3]
        try state.apply(.draw, rules: rules3)
        XCTAssertEqual(state.waste.count, 3)
        XCTAssertEqual(state.waste.last, expectedTop)
        // 24 cards = 8 draws.
        for _ in 0..<7 { try state.apply(.draw, rules: rules3) }
        XCTAssertTrue(state.stock.isEmpty)
    }

    func testVegasLimitsRecycles() throws {
        let vegas = KlondikeRules.vegas(drawCount: 1)
        var state = KlondikeState.deal(seed: 3)
        for _ in 0..<24 { try state.apply(.draw, rules: vegas) }
        XCTAssertFalse(state.canDraw(rules: vegas))
        XCTAssertThrowsError(try state.apply(.draw, rules: vegas))
        XCTAssertEqual(KlondikeRules.vegas(drawCount: 3).maxRecycles, 2)
    }

    func testFoundationAndTableauRules() throws {
        let aceSpades = Card(rank: 1, suit: .spades)
        let twoSpades = Card(rank: 2, suit: .spades)
        let kingHearts = Card(rank: 13, suit: .hearts)
        let queenClubs = Card(rank: 12, suit: .clubs)
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [twoSpades, aceSpades], faceDownCount: 0)
        tableau[1] = Column(cards: [kingHearts], faceDownCount: 0)
        tableau[2] = Column(cards: [Card(rank: 5, suit: .clubs), queenClubs], faceDownCount: 1)
        var state = KlondikeState(stock: [], waste: [], foundations: [0, 0, 0, 0], tableau: tableau)

        XCTAssertTrue(state.isLegal(.tableauToFoundation(0), rules: rules))
        XCTAssertFalse(state.isLegal(.tableauToFoundation(1), rules: rules))
        try state.apply(.tableauToFoundation(0), rules: rules)
        try state.apply(.tableauToFoundation(0), rules: rules)
        XCTAssertEqual(state.foundations[Suit.spades.rawValue], 2)

        XCTAssertTrue(state.isLegal(.tableauToTableau(from: 2, count: 1, to: 1), rules: rules))
        let outcome = try state.apply(.tableauToTableau(from: 2, count: 1, to: 1), rules: rules)
        XCTAssertTrue(outcome.revealedCard)
        XCTAssertEqual(state.tableau[2].faceDownCount, 0)

        // King to empty column.
        XCTAssertTrue(state.isLegal(.tableauToTableau(from: 1, count: 2, to: 0), rules: rules))
        // Non-king to empty column is illegal.
        XCTAssertFalse(state.isLegal(.tableauToTableau(from: 2, count: 1, to: 3), rules: rules))
        // Foundation back to tableau.
        state.tableau[4] = Column(cards: [Card(rank: 3, suit: .hearts)], faceDownCount: 0)
        XCTAssertTrue(state.isLegal(.foundationToTableau(.spades, 4), rules: rules))
        XCTAssertFalse(state.isLegal(.foundationToTableau(.hearts, 4), rules: rules))
    }

    func testIllegalMovesAreRejected() {
        let state = KlondikeState.deal(seed: 9)
        XCTAssertFalse(state.isLegal(.wasteToFoundation, rules: rules))
        XCTAssertFalse(state.isLegal(.tableauToTableau(from: 0, count: 2, to: 1), rules: rules))
        XCTAssertFalse(state.isLegal(.tableauToTableau(from: 0, count: 1, to: 0), rules: rules))
        XCTAssertFalse(state.isLegal(.tableauToTableau(from: 9, count: 1, to: 0), rules: rules))
        XCTAssertFalse(state.isLegal(.wasteToTableau(8), rules: rules))
    }

    func testLegalMovesAreAllLegal() throws {
        for seed in UInt64(1)...25 {
            var state = KlondikeState.deal(seed: seed)
            var rng = SeededRandom(seed: seed)
            for _ in 0..<200 {
                let moves = state.legalMoves(rules: rules)
                guard !moves.isEmpty else { break }
                for move in moves { XCTAssertTrue(state.isLegal(move, rules: rules), "\(move)") }
                try state.apply(moves[rng.next(below: moves.count)], rules: rules)
                // Invariant: still 52 distinct cards.
                let cards = state.stock + state.waste + state.tableau.flatMap(\.cards)
                XCTAssertEqual(cards.count + state.foundationCount, 52)
                XCTAssertEqual(Set(cards).count, cards.count)
                // Invariant: face-up runs are valid sequences.
                for column in state.tableau where column.faceUpCount > 1 {
                    let run = Array(column.faceUp)
                    for i in 1..<run.count { XCTAssertTrue(run[i].canStack(on: run[i - 1])) }
                }
            }
        }
    }

    func testCardAtLocation() {
        let state = KlondikeState.deal(seed: 1)
        XCTAssertEqual(state.card(at: .tableau(column: 0, index: 0)), state.tableau[0].cards[0])
        XCTAssertNil(state.card(at: .tableau(column: 0, index: 3)))
        XCTAssertNil(state.card(at: .waste))
        XCTAssertNil(state.card(at: .foundation(.hearts)))
        XCTAssertEqual(state.card(at: .stock), state.stock.last)
    }
}
