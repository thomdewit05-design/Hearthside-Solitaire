import XCTest
@testable import HearthsideCore

final class SolverTests: XCTestCase {
    func replay(_ moves: [Move], from start: KlondikeState, rules: KlondikeRules) throws -> KlondikeState {
        var state = start
        for move in moves { try state.apply(move, rules: rules) }
        return state
    }

    func testSolutionsAreProofs() throws {
        for rules in [KlondikeRules.standard(drawCount: 1), .standard(drawCount: 3), .vegas(drawCount: 3)] {
            let solver = KlondikeSolver(rules: rules, nodeBudget: 30_000)
            var winnable = 0
            for seed in UInt64(1)...12 {
                let start = KlondikeState.deal(seed: seed)
                let result = solver.solve(start)
                if result.verdict == .winnable {
                    winnable += 1
                    XCTAssertTrue(try replay(result.solution, from: start, rules: rules).isWon, "seed \(seed) \(rules)")
                } else {
                    XCTAssertTrue(result.solution.isEmpty)
                }
            }
            XCTAssertGreaterThan(winnable, rules.drawCount == 1 ? 7 : 2, "\(rules)")
        }
    }

    func testAlreadyWonPosition() {
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 13, suit: .hearts)], faceDownCount: 0)
        let state = KlondikeState(stock: [], waste: [], foundations: [13, 12, 13, 13], tableau: tableau)
        let result = KlondikeSolver(rules: .standard()).solve(state)
        XCTAssertEqual(result.verdict, .winnable)
        XCTAssertEqual(result.solution, [.tableauToFoundation(0)])
    }

    func testUnwinnablePositionIsDetected() {
        // 2♠ buried under K♠ in one column with nothing else to move.
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 2, suit: .spades), Card(rank: 13, suit: .spades)], faceDownCount: 1)
        let state = KlondikeState(stock: [], waste: [], foundations: [1, 13, 13, 13], tableau: tableau)
        // K♠ can move to an empty column, which reveals 2♠ — so this *is* winnable.
        XCTAssertEqual(KlondikeSolver(rules: .standard()).solve(state).verdict, .winnable)

        // Without an empty column (all others hold a queen that can't move), it is stuck.
        var stuck = Array(repeating: Column(cards: [Card(rank: 12, suit: .clubs)], faceDownCount: 0), count: 7)
        stuck[0] = Column(cards: [Card(rank: 2, suit: .spades), Card(rank: 5, suit: .hearts)], faceDownCount: 1)
        let blocked = KlondikeState(stock: [], waste: [], foundations: [1, 3, 11, 13], tableau: stuck)
        XCTAssertEqual(KlondikeSolver(rules: .standard()).solve(blocked).verdict, .unwinnable)
    }

    func testBudgetExhaustionReportsUnknown() {
        let solver = KlondikeSolver(rules: .standard(drawCount: 3), nodeBudget: 5)
        var sawUnknown = false
        for seed in UInt64(1)...10 where solver.solve(.deal(seed: seed)).verdict == .unknown { sawUnknown = true }
        XCTAssertTrue(sawUnknown)
    }

    func testHintIsAlwaysAGoodMove() throws {
        let rules = KlondikeRules.standard(drawCount: 1)
        let solver = KlondikeSolver(rules: rules, nodeBudget: 60_000)
        for seed in UInt64(1)...10 {
            var state = KlondikeState.deal(seed: seed)
            guard solver.solve(state).verdict == .winnable else { continue }
            // Following hints all the way must win.
            var steps = 0
            while !state.isWon && steps < 400, let hint = solver.hint(for: state) {
                XCTAssertTrue(state.isLegal(hint, rules: rules))
                try state.apply(hint, rules: rules)
                steps += 1
            }
            XCTAssertTrue(state.isWon, "seed \(seed)")
            return
        }
        XCTFail("no winnable deal found")
    }

    func testDealGeneratorSplitsIntoThirds() throws {
        let generator = DealGenerator(rules: .standard(drawCount: 1), nodeBudget: 40_000)
        let report = generator.generate(count: 30)
        XCTAssertEqual(report.winnable, 30)
        XCTAssertEqual(report.library.totalCount, 30)
        XCTAssertGreaterThan(report.library.easy.count, 5)
        XCTAssertGreaterThan(report.library.normal.count, 5)
        XCTAssertGreaterThan(report.library.hard.count, 5)
        XCTAssertGreaterThanOrEqual(report.attempted, 30)
        XCTAssertGreaterThan(report.averageMilliseconds, 0)
        // Every listed seed is really winnable.
        let solver = KlondikeSolver(rules: .standard(drawCount: 1), nodeBudget: 40_000)
        for seed in report.library.hard.prefix(3) {
            XCTAssertEqual(solver.solve(.deal(seed: seed)).verdict, .winnable)
        }
        // Round trip through the file format.
        let data = try report.library.encoded()
        XCTAssertEqual(try DealLibrary.load(from: data), report.library)
        XCTAssertEqual(DealGenerator.quantile([], 0.5), 0)
    }

    func testDealPicker() {
        let library = DealLibrary(drawCount: 1, easy: [1, 2], normal: [3, 4], hard: [5, 6])
        let picker = DealPicker(library: library, newPlayerEasyGames: 5, hardShare: 0.5)
        var rng = SeededRandom(seed: 1)
        for games in 0..<5 {
            let deal = picker.nextDeal(gamesPlayed: games, alwaysWinnable: true, using: &rng)
            XCTAssertEqual(deal.difficulty, .easy)
            XCTAssertTrue(library.easy.contains(deal.seed))
        }
        var seen = Set<DealDifficulty>()
        for _ in 0..<50 {
            let deal = picker.nextDeal(gamesPlayed: 10, alwaysWinnable: true, using: &rng)
            seen.insert(deal.difficulty!)
            XCTAssertTrue(deal.winnable)
        }
        XCTAssertEqual(seen, [.normal, .hard])
        let avoid = picker.nextDeal(gamesPlayed: 0, alwaysWinnable: true, recentSeeds: [1], using: &rng)
        XCTAssertEqual(avoid.seed, 2)
        let random = picker.nextDeal(gamesPlayed: 10, alwaysWinnable: false, using: &rng)
        XCTAssertFalse(random.winnable)
        XCTAssertLessThan(random.seed, 1 << 53, "JSON-safe seed")
    }
}
