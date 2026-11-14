import XCTest
@testable import HearthsideCore

final class KlondikeGameTests: XCTestCase {
    func makeGame(_ rules: KlondikeRules = .standard(drawCount: 1), seed: UInt64 = 5) -> KlondikeGame {
        KlondikeGame(deal: DealInfo(seed: seed, winnable: false), rules: rules)
    }

    /// Small hand-built position for precise checks.
    func customGame(rules: KlondikeRules = .standard(drawCount: 1)) -> KlondikeGame {
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 9, suit: .clubs), Card(rank: 1, suit: .hearts)], faceDownCount: 1)
        tableau[1] = Column(cards: [Card(rank: 8, suit: .spades)], faceDownCount: 0)
        tableau[2] = Column(cards: [Card(rank: 10, suit: .clubs), Card(rank: 9, suit: .diamonds)], faceDownCount: 1)
        tableau[3] = Column(cards: [Card(rank: 13, suit: .spades)], faceDownCount: 0)
        let state = KlondikeState(stock: [Card(rank: 2, suit: .hearts)],
                                  waste: [Card(rank: 7, suit: .diamonds)],
                                  foundations: [0, 0, 0, 0], tableau: tableau)
        return KlondikeGame(state: state, rules: rules, deal: DealInfo(seed: 0, winnable: false))
    }

    func testUndoRestoresEverything() throws {
        var game = makeGame()
        let start = game.state
        try game.perform(.draw)
        try game.perform(.draw)
        XCTAssertEqual(game.moveCount, 2)
        XCTAssertTrue(game.undo())
        XCTAssertTrue(game.undo())
        XCTAssertFalse(game.undo())
        XCTAssertEqual(game.state, start)
        XCTAssertEqual(game.moveCount, 0)
        XCTAssertEqual(game.undoCount, 2)
    }

    func testUnlimitedUndo() throws {
        var game = makeGame()
        for _ in 0..<500 { try game.perform(.draw) }
        var undone = 0
        while game.undo() { undone += 1 }
        XCTAssertEqual(undone, 500)
        XCTAssertEqual(game.state, KlondikeState.deal(seed: 5))
    }

    func testStandardScoring() throws {
        var game = customGame()
        try game.perform(.tableauToFoundation(0)) // +10, reveals +5
        XCTAssertEqual(game.score, 15)
        try game.perform(.wasteToTableau(1)) // 7♦ on 8♠: +5
        XCTAssertEqual(game.score, 20)
    }

    func testStandardScoringFoundationBack() throws {
        var game = customGame()
        try game.perform(.tableauToFoundation(0))
        XCTAssertThrowsError(try game.perform(.foundationToTableau(.hearts, 4)))
        XCTAssertEqual(game.score, 15)
    }

    func testRecyclePenaltyAndClamp() throws {
        var game = makeGame()
        for _ in 0..<24 { try game.perform(.draw) }
        try game.perform(.draw) // recycle: -100, clamped at 0
        XCTAssertEqual(game.score, 0)
    }

    func testVegasScoring() throws {
        var game = customGame(rules: .vegas(drawCount: 1))
        XCTAssertEqual(game.score, -52)
        try game.perform(.tableauToFoundation(0))
        XCTAssertEqual(game.score, -47)
    }

    func testTapPrefersFoundation() {
        let game = customGame()
        XCTAssertEqual(game.bestMove(forTapAt: .tableau(column: 0, index: 1)), .tableauToFoundation(0))
        XCTAssertEqual(game.bestMove(forTapAt: .waste), .wasteToTableau(1))
        XCTAssertEqual(game.bestMove(forTapAt: .stock), .draw)
        XCTAssertNil(game.bestMove(forTapAt: .tableau(column: 0, index: 0)), "face-down cards can't be tapped")
        XCTAssertNil(game.bestMove(forTapAt: .tableau(column: 3, index: 0)), "lone king stays put")
        XCTAssertNil(game.bestMove(forTapAt: .foundation(.spades)))
    }

    func testTapMovesStackToColumn() throws {
        var game = customGame()
        try game.perform(.wasteToTableau(1)) // 8♠ 7♦
        // 9♦ can't go on 8♠; but 8♠+7♦ can go on 9♦.
        XCTAssertEqual(game.bestMove(forTapAt: .tableau(column: 1, index: 0)),
                       .tableauToTableau(from: 1, count: 2, to: 2))
    }

    func testDragAndDrop() {
        let game = customGame()
        XCTAssertEqual(game.move(from: .waste, to: .tableau(1)), .wasteToTableau(1))
        XCTAssertNil(game.move(from: .waste, to: .tableau(0)))
        XCTAssertEqual(game.move(from: .tableau(column: 0, index: 1), to: .foundation(.hearts)), .tableauToFoundation(0))
        XCTAssertNil(game.move(from: .tableau(column: 0, index: 1), to: .foundation(.spades)), "wrong suit slot")
        XCTAssertNil(game.move(from: .tableau(column: 2, index: 0), to: .tableau(1)), "face-down")
        XCTAssertEqual(game.move(from: .tableau(column: 3, index: 0), to: .tableau(5)),
                       .tableauToTableau(from: 3, count: 1, to: 5))
    }

    func testAutoComplete() throws {
        // Everything face up, two suits left in neat columns.
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 13, suit: .hearts), Card(rank: 12, suit: .spades)], faceDownCount: 0)
        tableau[1] = Column(cards: [Card(rank: 13, suit: .spades), Card(rank: 12, suit: .hearts)], faceDownCount: 0)
        let state = KlondikeState(stock: [], waste: [], foundations: [11, 11, 13, 13], tableau: tableau)
        var game = KlondikeGame(state: state, rules: .standard(), deal: DealInfo(seed: 0, winnable: true))
        XCTAssertTrue(game.canAutoComplete)
        let moves = game.autoCompleteMoves()
        XCTAssertEqual(moves.count, 4)
        for move in moves { try game.perform(move) }
        XCTAssertTrue(game.isWon)
        XCTAssertFalse(game.canAutoComplete)
    }

    func testAutoCompleteNotOfferedWithHiddenCards() {
        XCTAssertFalse(makeGame().canAutoComplete)
        XCTAssertTrue(makeGame().autoCompleteMoves().isEmpty)
    }

    func testAutoCompleteWithStockDrawOne() throws {
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 13, suit: .hearts)], faceDownCount: 0)
        let state = KlondikeState(stock: [Card(rank: 12, suit: .hearts)], waste: [Card(rank: 11, suit: .hearts)],
                                  foundations: [13, 10, 13, 13], tableau: tableau)
        var game = KlondikeGame(state: state, rules: .standard(), deal: DealInfo(seed: 0, winnable: true))
        XCTAssertTrue(game.canAutoComplete)
        for move in game.autoCompleteMoves() { try game.perform(move) }
        XCTAssertTrue(game.isWon)
        // Draw-3 with a stock: not offered.
        let game3 = KlondikeGame(state: state, rules: .standard(drawCount: 3), deal: DealInfo(seed: 0, winnable: true))
        XCTAssertFalse(game3.canAutoComplete)
    }

    func testResumeAfterQuitRoundTrip() throws {
        var game = makeGame(.vegas(drawCount: 3), seed: 77)
        try game.perform(.draw)
        game.elapsed = 42
        game.registerHint()
        let data = try JSONEncoder().encode(game)
        var restored = try JSONDecoder().decode(KlondikeGame.self, from: data)
        XCTAssertEqual(restored, game)
        XCTAssertEqual(restored.hintsUsed, 1)
        XCTAssertTrue(restored.undo(), "undo history survives a restart")
    }
}
