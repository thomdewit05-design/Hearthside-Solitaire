import Foundation

/// Dutch/EU energy labels (NTA 8800 scale). Every house starts at G; each measure
/// raises the label one step. Houses with 7 or 8 measures go beyond A to A+ / A++.
public enum EnergyLabel: Int, Codable, Sendable, CaseIterable, Comparable {
    case g = 0, f, e, d, c, b, a, aPlus, aPlusPlus

    public var title: String {
        switch self {
        case .g: return "G"
        case .f: return "F"
        case .e: return "E"
        case .d: return "D"
        case .c: return "C"
        case .b: return "B"
        case .a: return "A"
        case .aPlus: return "A+"
        case .aPlusPlus: return "A++"
        }
    }

    /// Official label colour (RGB hex) for the badge.
    public var colorHex: UInt32 {
        switch self {
        case .g: return 0xE30613
        case .f: return 0xEE7203
        case .e: return 0xF9B000
        case .d: return 0xFFED00
        case .c: return 0xC8D300
        case .b: return 0x55B030
        case .a: return 0x009640
        case .aPlus: return 0x008237
        case .aPlusPlus: return 0x006E2E
        }
    }

    /// 0 (cold, grey) … 1 (warm, glowing). Drives the village illustration.
    public var warmth: Double { Double(rawValue) / Double(EnergyLabel.aPlusPlus.rawValue) }

    public func raised(by steps: Int) -> EnergyLabel {
        EnergyLabel(rawValue: min(EnergyLabel.aPlusPlus.rawValue, rawValue + steps)) ?? .aPlusPlus
    }

    public static func < (lhs: EnergyLabel, rhs: EnergyLabel) -> Bool { lhs.rawValue < rhs.rawValue }
}
