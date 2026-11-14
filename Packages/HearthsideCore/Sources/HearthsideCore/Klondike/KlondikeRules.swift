import Foundation

public enum ScoringMode: String, Codable, Sendable, CaseIterable {
    /// Classic points: +5/+10 per useful move, penalty for recycling the stock.
    case standard
    /// "Vegas" style points only — never real money. Starts at -52, +5 per
    /// foundation card, limited passes through the stock.
    case vegas
}

public struct KlondikeRules: Codable, Hashable, Sendable {
    /// 1 or 3 cards per draw.
    public var drawCount: Int
    public var scoring: ScoringMode
    /// Number of times the waste may be turned back into the stock. `nil` = unlimited.
    public var maxRecycles: Int?

    public init(drawCount: Int, scoring: ScoringMode, maxRecycles: Int?) {
        precondition(drawCount == 1 || drawCount == 3, "Klondike draws 1 or 3 cards")
        self.drawCount = drawCount
        self.scoring = scoring
        self.maxRecycles = maxRecycles
    }

    public static func standard(drawCount: Int = 1) -> KlondikeRules {
        KlondikeRules(drawCount: drawCount, scoring: .standard, maxRecycles: nil)
    }

    /// Vegas: one pass with draw-1, three passes (two recycles) with draw-3.
    public static func vegas(drawCount: Int = 1) -> KlondikeRules {
        KlondikeRules(drawCount: drawCount, scoring: .vegas, maxRecycles: drawCount == 1 ? 0 : 2)
    }

    public static func make(drawCount: Int, scoring: ScoringMode) -> KlondikeRules {
        scoring == .vegas ? .vegas(drawCount: drawCount) : .standard(drawCount: drawCount)
    }
}
