import Foundation

/// Point rules. Points are purely cosmetic; there is never any money involved.
public enum Scoring {
    public static let vegasStart = -52

    public static func initialScore(_ rules: KlondikeRules) -> Int {
        rules.scoring == .vegas ? vegasStart : 0
    }

    public static func delta(for move: Move, outcome: MoveOutcome, rules: KlondikeRules) -> Int {
        switch rules.scoring {
        case .vegas:
            switch move {
            case .wasteToFoundation, .tableauToFoundation: return 5
            case .foundationToTableau: return -5
            default: return 0
            }
        case .standard:
            var points = 0
            switch move {
            case .wasteToTableau: points += 5
            case .wasteToFoundation, .tableauToFoundation: points += 10
            case .foundationToTableau: points -= 15
            case .draw where outcome.recycled: points -= rules.drawCount == 1 ? 100 : 20
            default: break
            }
            if outcome.revealedCard { points += 5 }
            return points
        }
    }

    /// Standard scoring clamps at zero like most classic implementations.
    public static func clamp(_ score: Int, rules: KlondikeRules) -> Int {
        rules.scoring == .standard ? max(0, score) : score
    }
}
