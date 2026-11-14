import Foundation

/// Every action a player (or the solver) can take.
public enum Move: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Turn cards from the stock to the waste, or recycle the waste when the stock is empty.
    case draw
    case wasteToFoundation
    case wasteToTableau(Int)
    case tableauToFoundation(Int)
    case tableauToTableau(from: Int, count: Int, to: Int)
    case foundationToTableau(Suit, Int)

    public var description: String {
        switch self {
        case .draw: return "draw"
        case .wasteToFoundation: return "W→F"
        case .wasteToTableau(let col): return "W→T\(col)"
        case .tableauToFoundation(let col): return "T\(col)→F"
        case let .tableauToTableau(from, count, to): return "T\(from)→T\(to)×\(count)"
        case let .foundationToTableau(suit, col): return "F\(suit.symbol)→T\(col)"
        }
    }
}

/// Where a card currently lies, used for taps, drags and hints in the UI.
public enum CardLocation: Hashable, Codable, Sendable {
    case stock
    case waste
    case foundation(Suit)
    /// `index` is the position in the column (0 = bottom, nearest the table edge).
    case tableau(column: Int, index: Int)
}

/// A pile a card can be dropped on.
public enum PileTarget: Hashable, Codable, Sendable {
    case foundation(Suit)
    case tableau(Int)
}

public extension Move {
    /// The pile the move puts cards on, if any (for animations and hints).
    var target: PileTarget? {
        switch self {
        case .draw: return nil
        case .wasteToFoundation, .tableauToFoundation: return nil // suit known from card
        case .wasteToTableau(let col), .foundationToTableau(_, let col): return .tableau(col)
        case .tableauToTableau(_, _, let to): return .tableau(to)
        }
    }

    var isFoundationMove: Bool {
        switch self {
        case .wasteToFoundation, .tableauToFoundation: return true
        default: return false
        }
    }
}
