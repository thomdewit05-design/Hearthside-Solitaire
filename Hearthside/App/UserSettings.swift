import Foundation
import HearthsideCore

enum CardSize: String, Codable, CaseIterable, Identifiable {
    case standard, extraLarge
    var id: String { rawValue }
    var titleKey: String { self == .standard ? "settings.cardsize.standard" : "settings.cardsize.large" }
}

/// Player preferences (local only, not synced).
struct UserSettings: Codable, Equatable {
    var drawCount = 1
    var scoring: ScoringMode = .standard
    var alwaysWinnable = true
    var cardSize: CardSize = .standard
    var highContrast = false
    var leftHanded = false
    var soundEnabled = true
    var hapticsEnabled = true
    var showTimer = true
    var autoCompleteEnabled = true

    var rules: KlondikeRules { .make(drawCount: drawCount, scoring: scoring) }
}
