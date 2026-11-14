import Foundation

/// Depth-first Klondike solver with a transposition table and move-ordering heuristics.
///
/// * A returned solution is a *proof*: replaying it from the start position wins.
/// * Stock/waste handling uses "talon macro moves": every card that can become the
///   waste top within one pass is a candidate, so the search never branches on
///   individual draws.
/// * Forced "safe" foundation moves are played without branching.
/// * Foundation→tableau moves are not searched, so `.unknown` does not mean unwinnable.
public struct KlondikeSolver: Sendable {
    public enum Verdict: String, Sendable, Codable {
        case winnable
        /// Every reachable position was explored without a win.
        case unwinnable
        /// The node budget ran out first.
        case unknown
    }

    public struct Result: Sendable {
        public var verdict: Verdict
        /// Full move list (including individual draws) from the given position.
        public var solution: [Move]
        public var nodesExplored: Int
        public var deadEnds: Int
        public var seconds: Double

        /// Higher = harder. Combines search effort, dead ends and solution length.
        public var difficultyScore: Double {
            Double(nodesExplored) + Double(deadEnds) * 4 + Double(solution.count) * 0.5
        }
    }

    public let rules: KlondikeRules
    public let nodeBudget: Int

    public init(rules: KlondikeRules, nodeBudget: Int = 150_000) {
        self.rules = rules
        self.nodeBudget = nodeBudget
    }

    public func solve(_ start: KlondikeState) -> Result {
        let clock = Date()
        var search = Search(rules: rules, budget: nodeBudget)
        var state = start
        let won = search.dfs(&state)
        let verdict: Verdict = won ? .winnable : (search.aborted ? .unknown : .unwinnable)
        return Result(verdict: verdict,
                      solution: won ? search.path : [],
                      nodesExplored: search.nodes,
                      deadEnds: search.deadEnds,
                      seconds: Date().timeIntervalSince(clock))
    }

    /// First move of a proven solution, or `nil` when none was found within budget.
    public func hint(for state: KlondikeState) -> Move? {
        let result = solve(state)
        return result.verdict == .winnable ? result.solution.first : nil
    }

    // MARK: - Search

    private struct Search {
        let rules: KlondikeRules
        let budget: Int
        var nodes = 0
        var deadEnds = 0
        var aborted = false
        var path: [Move] = []
        var visited = Set<UInt64>()

        init(rules: KlondikeRules, budget: Int) {
            self.rules = rules
            self.budget = budget
            visited.reserveCapacity(min(budget, 1 << 18))
        }

        mutating func dfs(_ state: inout KlondikeState) -> Bool {
            nodes += 1
            if nodes > budget {
                aborted = true
                return false
            }
            let pathMark = path.count
            playSafeMoves(&state)
            if isEffectivelyWon(state) {
                finish(&state)
                return true
            }
            guard visited.insert(key(of: state)).inserted else {
                path.removeSubrange(pathMark...)
                return false
            }
            for candidate in candidates(state) {
                var next = state
                let mark = path.count
                for _ in 0..<candidate.draws {
                    next.applyUnchecked(.draw, rules: rules)
                    path.append(.draw)
                }
                next.applyUnchecked(candidate.move, rules: rules)
                path.append(candidate.move)
                if dfs(&next) {
                    state = next
                    return true
                }
                path.removeSubrange(mark...)
                if aborted { break }
            }
            deadEnds += 1
            path.removeSubrange(pathMark...)
            return false
        }

        /// Won, or trivially winnable (all cards visible and reachable).
        func isEffectivelyWon(_ state: KlondikeState) -> Bool {
            if state.isWon { return true }
            guard state.faceDownTotal == 0 else { return false }
            if state.stock.isEmpty && state.waste.isEmpty { return true }
            return rules.drawCount == 1 && rules.maxRecycles == nil
        }

        /// Plays out a trivially-won position so the solution is a complete move list.
        mutating func finish(_ state: inout KlondikeState) {
            var guardCounter = 0
            while !state.isWon && guardCounter < 3_000 {
                guardCounter += 1
                var played = false
                if let card = state.waste.last, state.canMoveToFoundation(card) {
                    state.applyUnchecked(.wasteToFoundation, rules: rules)
                    path.append(.wasteToFoundation)
                    played = true
                } else {
                    for col in 0..<7 {
                        if let card = state.tableau[col].top, state.canMoveToFoundation(card) {
                            state.applyUnchecked(.tableauToFoundation(col), rules: rules)
                            path.append(.tableauToFoundation(col))
                            played = true
                            break
                        }
                    }
                }
                if !played {
                    guard state.canDraw(rules: rules) else { return }
                    state.applyUnchecked(.draw, rules: rules)
                    path.append(.draw)
                }
            }
        }

        /// A foundation move that can never hurt: low cards, or when both
        /// opposite-colour foundations are high enough that nothing needs this card.
        func isSafeToFoundation(_ card: Card, _ state: KlondikeState) -> Bool {
            guard state.canMoveToFoundation(card) else { return false }
            if card.rank <= 2 { return true }
            let f = state.foundations
            let opposite: (Int, Int) = card.isRed ? (f[Suit.spades.rawValue], f[Suit.clubs.rawValue])
                                                  : (f[Suit.hearts.rawValue], f[Suit.diamonds.rawValue])
            let sameOther: Int
            switch card.suit {
            case .spades: sameOther = f[Suit.clubs.rawValue]
            case .clubs: sameOther = f[Suit.spades.rawValue]
            case .hearts: sameOther = f[Suit.diamonds.rawValue]
            case .diamonds: sameOther = f[Suit.hearts.rawValue]
            }
            return opposite.0 >= card.rank - 1 && opposite.1 >= card.rank - 1 && sameOther >= card.rank - 2
        }

        mutating func playSafeMoves(_ state: inout KlondikeState) {
            var progressed = true
            while progressed {
                progressed = false
                for col in 0..<7 {
                    if let card = state.tableau[col].top, isSafeToFoundation(card, state) {
                        state.applyUnchecked(.tableauToFoundation(col), rules: rules)
                        path.append(.tableauToFoundation(col))
                        progressed = true
                    }
                }
                if let card = state.waste.last, isSafeToFoundation(card, state) {
                    state.applyUnchecked(.wasteToFoundation, rules: rules)
                    path.append(.wasteToFoundation)
                    progressed = true
                }
            }
        }

        struct Candidate {
            var draws: Int
            var move: Move
            var priority: Int
        }

        /// Cards reachable as waste top within one full cycle, with the draws needed.
        func talonReachable(_ state: KlondikeState) -> [(draws: Int, card: Card)] {
            var result: [(Int, Card)] = []
            var seen = Set<UInt8>()
            if let top = state.waste.last {
                result.append((0, top))
                seen.insert(top.raw)
            }
            var sim = state
            let maxSteps = (state.stock.count + state.waste.count) * 2 + 4
            var draws = 0
            while draws < maxSteps && sim.canDraw(rules: rules) {
                sim.applyUnchecked(.draw, rules: rules)
                draws += 1
                if sim.stock.count == state.stock.count && sim.waste.count == state.waste.count
                    && sim.recycles > state.recycles { break } // back where we started
                if let top = sim.waste.last, seen.insert(top.raw).inserted {
                    result.append((draws, top))
                }
            }
            return result
        }

        func candidates(_ state: KlondikeState) -> [Candidate] {
            var list: [Candidate] = []
            let tableau = state.tableau
            let firstEmpty = tableau.firstIndex { $0.isEmpty }

            // Tableau → foundation (non-safe ones).
            for col in 0..<7 {
                if let card = tableau[col].top, state.canMoveToFoundation(card) {
                    let reveals = tableau[col].faceUpCount == 1 && tableau[col].faceDownCount > 0
                    list.append(Candidate(draws: 0, move: .tableauToFoundation(col), priority: reveals ? 1_000 : 600))
                }
            }

            // Tableau → tableau.
            for from in 0..<7 {
                let source = tableau[from]
                guard source.faceUpCount > 0 else { continue }
                let base = source.faceDownCount
                for start in base..<source.cards.count {
                    let card = source.cards[start]
                    let wholeRun = start == base
                    if !wholeRun {
                        // Partial moves only when they free a card for the foundation.
                        let exposed = source.cards[start - 1]
                        guard state.canMoveToFoundation(exposed) else { continue }
                    }
                    for to in 0..<7 where to != from {
                        let target = tableau[to]
                        if target.isEmpty {
                            guard card.rank == 13, to == firstEmpty, wholeRun, base > 0 else { continue }
                            list.append(Candidate(draws: 0,
                                                  move: .tableauToTableau(from: from, count: source.cards.count - start, to: to),
                                                  priority: 700 + base * 10))
                        } else if let top = target.top, card.canStack(on: top) {
                            let priority: Int
                            if wholeRun && base > 0 {
                                priority = 800 + base * 10
                            } else if wholeRun {
                                priority = 300 // empties a column
                            } else {
                                priority = 650
                            }
                            list.append(Candidate(draws: 0,
                                                  move: .tableauToTableau(from: from, count: source.cards.count - start, to: to),
                                                  priority: priority))
                        }
                    }
                }
            }

            // Talon → foundation / tableau.
            for (draws, card) in talonReachable(state) {
                if state.canMoveToFoundation(card) {
                    list.append(Candidate(draws: draws, move: .wasteToFoundation, priority: 900 - draws))
                }
                for to in 0..<7 {
                    let target = tableau[to]
                    if target.isEmpty {
                        guard card.rank == 13, to == firstEmpty else { continue }
                        list.append(Candidate(draws: draws, move: .wasteToTableau(to), priority: 450 - draws))
                    } else if let top = target.top, card.canStack(on: top) {
                        list.append(Candidate(draws: draws, move: .wasteToTableau(to), priority: 500 - draws))
                    }
                }
            }

            list.sort { $0.priority > $1.priority }
            return list
        }

        /// 64-bit FNV-1a fingerprint of the position. Column order is canonicalised
        /// because swapping two tableau columns never changes solvability.
        func key(of state: KlondikeState) -> UInt64 {
            var columnHashes: [UInt64] = []
            columnHashes.reserveCapacity(7)
            for column in state.tableau {
                var h: UInt64 = 0xcbf2_9ce4_8422_2325
                h = fnv(h, UInt8(column.faceDownCount))
                for card in column.cards { h = fnv(h, card.raw) }
                columnHashes.append(h)
            }
            columnHashes.sort()
            var h: UInt64 = 0xcbf2_9ce4_8422_2325
            for column in columnHashes {
                for shift in stride(from: 0, to: 64, by: 8) { h = fnv(h, UInt8(truncatingIfNeeded: column >> UInt64(shift))) }
            }
            for rank in state.foundations { h = fnv(h, UInt8(rank)) }
            // Talon in "fresh stock" order: waste bottom→top, then stock top→bottom.
            h = fnv(h, 0xFE)
            for card in state.waste { h = fnv(h, card.raw) }
            for card in state.stock.reversed() { h = fnv(h, card.raw) }
            // With unlimited draw-1 every talon position is reachable, so position is irrelevant.
            if !(rules.drawCount == 1 && rules.maxRecycles == nil) {
                h = fnv(h, UInt8(truncatingIfNeeded: state.waste.count))
            }
            if rules.maxRecycles != nil { h = fnv(h, UInt8(truncatingIfNeeded: state.recycles)) }
            return h
        }

        @inline(__always) func fnv(_ hash: UInt64, _ byte: UInt8) -> UInt64 {
            (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
    }
}
