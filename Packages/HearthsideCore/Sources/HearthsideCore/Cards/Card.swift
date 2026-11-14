import Foundation

/// The four French suits. The raw value is also the foundation slot index.
public enum Suit: Int, CaseIterable, Codable, Sendable, Hashable {
    case spades = 0
    case hearts = 1
    case clubs = 2
    case diamonds = 3

    public var isRed: Bool { self == .hearts || self == .diamonds }

    public var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .clubs: return "♣"
        case .diamonds: return "♦"
        }
    }

    /// Localization key used for VoiceOver ("harten zeven").
    public var nameKey: String {
        switch self {
        case .spades: return "suit.spades"
        case .hearts: return "suit.hearts"
        case .clubs: return "suit.clubs"
        case .diamonds: return "suit.diamonds"
        }
    }
}

/// A playing card packed into a single byte (0...51): `suit * 13 + (rank - 1)`.
public struct Card: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let raw: UInt8

    public init(raw: UInt8) {
        precondition(raw < 52, "Card raw value out of range")
        self.raw = raw
    }

    public init(rank: Int, suit: Suit) {
        precondition((1...13).contains(rank), "Rank must be 1...13")
        self.raw = UInt8(suit.rawValue * 13 + rank - 1)
    }

    /// 1 = ace ... 11 = jack, 12 = queen, 13 = king.
    @inline(__always) public var rank: Int { Int(raw % 13) + 1 }
    @inline(__always) public var suit: Suit { Suit(rawValue: Int(raw / 13))! }
    @inline(__always) public var isRed: Bool { suit.isRed }

    public var rankLabel: String {
        switch rank {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return String(rank)
        }
    }

    /// Localization key for the spoken rank ("rank.7", "rank.queen").
    public var rankNameKey: String {
        switch rank {
        case 1: return "rank.ace"
        case 11: return "rank.jack"
        case 12: return "rank.queen"
        case 13: return "rank.king"
        default: return "rank.\(rank)"
        }
    }

    public var description: String { rankLabel + suit.symbol }

    /// True when `self` may be placed on `other` in a tableau column.
    @inline(__always) public func canStack(on other: Card) -> Bool {
        other.rank == rank + 1 && other.isRed != isRed
    }

    public static func < (lhs: Card, rhs: Card) -> Bool { lhs.raw < rhs.raw }

    /// All 52 cards in a fixed, sorted order.
    public static let fullDeck: [Card] = (0..<52).map { Card(raw: UInt8($0)) }
}

extension Card: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(UInt8.self)
        guard value < 52 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid card \(value)"))
        }
        self.raw = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}
