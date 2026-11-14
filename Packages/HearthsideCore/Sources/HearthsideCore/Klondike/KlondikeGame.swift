import Foundation

public enum DealDifficulty: String, Codable, Sendable, CaseIterable {
    case easy, normal, hard
}

/// Where a deal came from: purely random, or a solver-proven winnable deal.
public struct DealInfo: Codable, Hashable, Sendable {
    public var seed: UInt64
    public var winnable: Bool
    public var difficulty: DealDifficulty?
    /// Set when this deal is the daily challenge for that day ("2026-11-14").
    public var dailyDate: String?

    public init(seed: UInt64, winnable: Bool, difficulty: DealDifficulty? = nil, dailyDate: String? = nil) {
        self.seed = seed
        self.winnable = winnable
        self.difficulty = difficulty
        self.dailyDate = dailyDate
    }
}

/// A playable game: position plus score, move counter, unlimited undo and timing.
/// Fully `Codable` so the app can resume exactly where the player left off.
public struct KlondikeGame: Codable, Sendable, Equatable {
    public struct Snapshot: Codable, Sendable, Equatable {
        public var state: KlondikeState
        public var score: Int
        public var moveCount: Int
    }

    public private(set) var state: KlondikeState
    public let rules: KlondikeRules
    public let deal: DealInfo
    public private(set) var score: Int
    public private(set) var moveCount: Int
    public private(set) var hintsUsed: Int = 0
    public private(set) var undoCount: Int = 0
    /// Seconds of active play; the app adds time while the table is on screen.
    public var elapsed: TimeInterval = 0
    private var history: [Snapshot] = []

    public init(deal: DealInfo, rules: KlondikeRules) {
        self.deal = deal
        self.rules = rules
        self.state = .deal(seed: deal.seed)
        self.score = Scoring.initialScore(rules)
        self.moveCount = 0
    }

    public init(state: KlondikeState, rules: KlondikeRules, deal: DealInfo) {
        self.deal = deal
        self.rules = rules
        self.state = state
        self.score = Scoring.initialScore(rules)
        self.moveCount = 0
    }

    public var isWon: Bool { state.isWon }
    public var canUndo: Bool { !history.isEmpty }
    public var hasStarted: Bool { moveCount > 0 || !history.isEmpty }

    // MARK: - Playing

    @discardableResult
    public mutating func perform(_ move: Move) throws -> MoveOutcome {
        guard state.isLegal(move, rules: rules) else { throw MoveError.illegal }
        history.append(Snapshot(state: state, score: score, moveCount: moveCount))
        let outcome = state.applyUnchecked(move, rules: rules)
        score = Scoring.clamp(score + Scoring.delta(for: move, outcome: outcome, rules: rules), rules: rules)
        moveCount += 1
        return outcome
    }

    /// Unlimited, free undo.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        state = last.state
        score = last.score
        moveCount = last.moveCount
        undoCount += 1
        return true
    }

    public mutating func registerHint() { hintsUsed += 1 }

    // MARK: - Tap: "put this card in the best place"

    /// Picks the most sensible move for a tap on a card, or `nil` if nothing fits.
    /// Priority: foundation → column with a face-up card (prefer revealing) → empty column.
    public func bestMove(forTapAt location: CardLocation) -> Move? {
        switch location {
        case .stock:
            return state.canDraw(rules: rules) ? .draw : nil
        case .waste:
            guard let card = state.waste.last else { return nil }
            if state.canMoveToFoundation(card) { return .wasteToFoundation }
            if let col = bestColumn(for: card, excluding: nil) { return .wasteToTableau(col) }
            return nil
        case .foundation(let suit):
            guard let card = state.foundationTop(suit) else { return nil }
            if let col = bestColumn(for: card, excluding: nil, allowEmpty: false) {
                return .foundationToTableau(suit, col)
            }
            return nil
        case let .tableau(column, index):
            guard state.tableau.indices.contains(column) else { return nil }
            let pile = state.tableau[column]
            guard pile.isFaceUp(index) else { return nil }
            let count = pile.cards.count - index
            let card = pile.cards[index]
            if count == 1, state.canMoveToFoundation(card) { return .tableauToFoundation(column) }
            // Don't shuffle a king that already sits alone at the bottom of a column.
            let isBareKing = index == 0 && card.rank == 13
            if let col = bestColumn(for: card, excluding: column, allowEmpty: !isBareKing) {
                return .tableauToTableau(from: column, count: count, to: col)
            }
            return nil
        }
    }

    private func bestColumn(for card: Card, excluding: Int?, allowEmpty: Bool = true) -> Int? {
        var emptyCandidate: Int?
        var best: (col: Int, score: Int)?
        for col in 0..<state.tableau.count where col != excluding {
            let pile = state.tableau[col]
            if pile.isEmpty {
                if allowEmpty && card.rank == 13 && emptyCandidate == nil { emptyCandidate = col }
                continue
            }
            guard state.canPlace(card, onColumn: col) else { continue }
            // Prefer longer face-up runs (keeps the table tidy), nearest column on ties.
            let score = pile.faceUpCount * 10 - abs(col - (excluding ?? col))
            if best == nil || score > best!.score { best = (col, score) }
        }
        return best?.col ?? emptyCandidate
    }

    // MARK: - Drag & drop

    /// Converts a drag from `location` onto `target` into a move, if legal.
    public func move(from location: CardLocation, to target: PileTarget) -> Move? {
        let candidate: Move?
        switch (location, target) {
        case (.waste, .foundation):
            candidate = .wasteToFoundation
        case (.waste, .tableau(let col)):
            candidate = .wasteToTableau(col)
        case let (.tableau(column, index), .foundation):
            candidate = index == state.tableau[column].cards.count - 1 ? .tableauToFoundation(column) : nil
        case let (.tableau(column, index), .tableau(col)):
            candidate = .tableauToTableau(from: column, count: state.tableau[column].cards.count - index, to: col)
        case let (.foundation(suit), .tableau(col)):
            candidate = .foundationToTableau(suit, col)
        default:
            candidate = nil
        }
        guard let move = candidate, state.isLegal(move, rules: rules) else { return nil }
        if case .foundation(let suit) = target, let card = state.card(at: location), card.suit != suit {
            return nil
        }
        return move
    }

    // MARK: - Auto-complete

    /// True when every card is face up and the rest can be finished automatically.
    public var canAutoComplete: Bool {
        guard !state.isWon, state.faceDownTotal == 0 else { return false }
        if state.stock.isEmpty && state.waste.isEmpty { return true }
        return rules.drawCount == 1 && rules.maxRecycles == nil
    }

    /// The sequence of moves that finishes the game from the current position.
    public func autoCompleteMoves() -> [Move] {
        guard canAutoComplete else { return [] }
        var sim = state
        var moves: [Move] = []
        var guardCounter = 0
        while !sim.isWon && guardCounter < 2_000 {
            guardCounter += 1
            if let move = Self.lowestFoundationMove(in: sim) {
                sim.applyUnchecked(move, rules: rules)
                moves.append(move)
            } else if sim.canDraw(rules: rules) {
                sim.applyUnchecked(.draw, rules: rules)
                moves.append(.draw)
            } else {
                return []
            }
        }
        return sim.isWon ? moves : []
    }

    private static func lowestFoundationMove(in state: KlondikeState) -> Move? {
        var best: (move: Move, rank: Int)?
        if let card = state.waste.last, state.canMoveToFoundation(card) {
            best = (.wasteToFoundation, card.rank)
        }
        for col in 0..<state.tableau.count {
            if let card = state.tableau[col].top, state.canMoveToFoundation(card),
               best == nil || card.rank < best!.rank {
                best = (.tableauToFoundation(col), card.rank)
            }
        }
        return best?.move
    }
}
