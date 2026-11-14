import Foundation

/// One tableau column: face-down cards first, then a face-up run.
public struct Column: Codable, Hashable, Sendable {
    public var cards: [Card]
    public var faceDownCount: Int

    public init(cards: [Card] = [], faceDownCount: Int = 0) {
        self.cards = cards
        self.faceDownCount = faceDownCount
    }

    public var isEmpty: Bool { cards.isEmpty }
    public var top: Card? { cards.last }
    public var faceUp: ArraySlice<Card> { cards[faceDownCount...] }
    public var faceUpCount: Int { cards.count - faceDownCount }

    public func isFaceUp(_ index: Int) -> Bool { index >= faceDownCount && index < cards.count }
}

/// What happened when a move was applied; used for scoring, sounds and animation.
public struct MoveOutcome: Sendable, Equatable {
    public var revealedCard: Bool = false
    public var recycled: Bool = false
    public var movedCards: [Card] = []
}

public enum MoveError: Error, Equatable {
    case illegal
}

/// The complete, value-typed position of a Klondike game.
public struct KlondikeState: Codable, Hashable, Sendable {
    /// `last` is the top card (next to be drawn).
    public var stock: [Card]
    /// `last` is the playable card.
    public var waste: [Card]
    /// Highest rank on each foundation, indexed by `Suit.rawValue` (0 = empty).
    public var foundations: [Int]
    public var tableau: [Column]
    /// How many times the waste has been turned back into the stock.
    public var recycles: Int

    public init(stock: [Card], waste: [Card], foundations: [Int], tableau: [Column], recycles: Int = 0) {
        self.stock = stock
        self.waste = waste
        self.foundations = foundations
        self.tableau = tableau
        self.recycles = recycles
    }

    /// Standard Klondike deal: column i gets i+1 cards with only the last face-up.
    public static func deal(seed: UInt64) -> KlondikeState {
        deal(deck: .shuffledDeck(seed: seed))
    }

    public static func deal(deck: [Card]) -> KlondikeState {
        precondition(deck.count == 52)
        var index = 0
        var tableau: [Column] = []
        for col in 0..<7 {
            let cards = Array(deck[index..<(index + col + 1)])
            index += col + 1
            tableau.append(Column(cards: cards, faceDownCount: col))
        }
        // The remaining 24 cards form the stock; deck order is draw order.
        let stock = Array(deck[index...].reversed())
        return KlondikeState(stock: stock, waste: [], foundations: [0, 0, 0, 0], tableau: tableau)
    }

    // MARK: - Queries

    public var foundationCount: Int { foundations.reduce(0, +) }
    public var isWon: Bool { foundationCount == 52 }
    public var faceDownTotal: Int { tableau.reduce(0) { $0 + $1.faceDownCount } }

    public func foundationTop(_ suit: Suit) -> Card? {
        let rank = foundations[suit.rawValue]
        return rank == 0 ? nil : Card(rank: rank, suit: suit)
    }

    @inline(__always) public func canMoveToFoundation(_ card: Card) -> Bool {
        foundations[card.suit.rawValue] == card.rank - 1
    }

    @inline(__always) public func canPlace(_ card: Card, onColumn col: Int) -> Bool {
        if let top = tableau[col].top {
            return tableau[col].faceDownCount < tableau[col].cards.count && card.canStack(on: top)
        }
        return card.rank == 13
    }

    public func canDraw(rules: KlondikeRules) -> Bool {
        if !stock.isEmpty { return true }
        guard !waste.isEmpty else { return false }
        if let limit = rules.maxRecycles { return recycles < limit }
        return true
    }

    /// The card at a location, if it exists and is face up (stock top counts as visible-able).
    public func card(at location: CardLocation) -> Card? {
        switch location {
        case .stock: return stock.last
        case .waste: return waste.last
        case .foundation(let suit): return foundationTop(suit)
        case let .tableau(column, index):
            guard tableau.indices.contains(column), tableau[column].cards.indices.contains(index) else { return nil }
            return tableau[column].cards[index]
        }
    }

    // MARK: - Legality

    public func isLegal(_ move: Move, rules: KlondikeRules) -> Bool {
        switch move {
        case .draw:
            return canDraw(rules: rules)
        case .wasteToFoundation:
            guard let card = waste.last else { return false }
            return canMoveToFoundation(card)
        case .wasteToTableau(let col):
            guard tableau.indices.contains(col), let card = waste.last else { return false }
            return canPlace(card, onColumn: col)
        case .tableauToFoundation(let col):
            guard tableau.indices.contains(col), let card = tableau[col].top,
                  tableau[col].faceUpCount > 0 else { return false }
            return canMoveToFoundation(card)
        case let .tableauToTableau(from, count, to):
            guard tableau.indices.contains(from), tableau.indices.contains(to), from != to,
                  count >= 1, count <= tableau[from].faceUpCount else { return false }
            let source = tableau[from]
            let moving = source.cards[source.cards.count - count]
            return canPlace(moving, onColumn: to)
        case let .foundationToTableau(suit, col):
            guard tableau.indices.contains(col), let card = foundationTop(suit) else { return false }
            return canPlace(card, onColumn: col)
        }
    }

    /// Every legal move in a stable order (foundation moves first).
    public func legalMoves(rules: KlondikeRules) -> [Move] {
        var moves: [Move] = []
        if let card = waste.last, canMoveToFoundation(card) { moves.append(.wasteToFoundation) }
        for col in 0..<tableau.count {
            if let card = tableau[col].top, tableau[col].faceUpCount > 0, canMoveToFoundation(card) {
                moves.append(.tableauToFoundation(col))
            }
        }
        if let card = waste.last {
            for col in 0..<tableau.count where canPlace(card, onColumn: col) {
                moves.append(.wasteToTableau(col))
            }
        }
        for from in 0..<tableau.count {
            let source = tableau[from]
            guard source.faceUpCount > 0 else { continue }
            for count in 1...source.faceUpCount {
                let moving = source.cards[source.cards.count - count]
                for to in 0..<tableau.count where to != from && canPlace(moving, onColumn: to) {
                    moves.append(.tableauToTableau(from: from, count: count, to: to))
                }
            }
        }
        for suit in Suit.allCases {
            guard let card = foundationTop(suit) else { continue }
            for col in 0..<tableau.count where canPlace(card, onColumn: col) {
                moves.append(.foundationToTableau(suit, col))
            }
        }
        if canDraw(rules: rules) { moves.append(.draw) }
        return moves
    }

    // MARK: - Applying moves

    /// Applies a move without checking legality. Callers must check `isLegal` first.
    @discardableResult
    public mutating func applyUnchecked(_ move: Move, rules: KlondikeRules) -> MoveOutcome {
        var outcome = MoveOutcome()
        switch move {
        case .draw:
            if stock.isEmpty {
                stock = waste.reversed()
                waste.removeAll(keepingCapacity: true)
                recycles += 1
                outcome.recycled = true
            } else {
                let count = min(rules.drawCount, stock.count)
                for _ in 0..<count {
                    let card = stock.removeLast()
                    waste.append(card)
                    outcome.movedCards.append(card)
                }
            }
        case .wasteToFoundation:
            let card = waste.removeLast()
            foundations[card.suit.rawValue] = card.rank
            outcome.movedCards = [card]
        case .wasteToTableau(let col):
            let card = waste.removeLast()
            tableau[col].cards.append(card)
            outcome.movedCards = [card]
        case .tableauToFoundation(let col):
            let card = tableau[col].cards.removeLast()
            foundations[card.suit.rawValue] = card.rank
            outcome.movedCards = [card]
            outcome.revealedCard = revealIfNeeded(col)
        case let .tableauToTableau(from, count, to):
            let start = tableau[from].cards.count - count
            let moving = Array(tableau[from].cards[start...])
            tableau[from].cards.removeSubrange(start...)
            tableau[to].cards.append(contentsOf: moving)
            outcome.movedCards = moving
            outcome.revealedCard = revealIfNeeded(from)
        case let .foundationToTableau(suit, col):
            let card = Card(rank: foundations[suit.rawValue], suit: suit)
            foundations[suit.rawValue] -= 1
            tableau[col].cards.append(card)
            outcome.movedCards = [card]
        }
        return outcome
    }

    @discardableResult
    public mutating func apply(_ move: Move, rules: KlondikeRules) throws -> MoveOutcome {
        guard isLegal(move, rules: rules) else { throw MoveError.illegal }
        return applyUnchecked(move, rules: rules)
    }

    private mutating func revealIfNeeded(_ col: Int) -> Bool {
        if tableau[col].faceDownCount > 0 && tableau[col].faceDownCount == tableau[col].cards.count {
            tableau[col].faceDownCount -= 1
            return true
        }
        return false
    }
}
