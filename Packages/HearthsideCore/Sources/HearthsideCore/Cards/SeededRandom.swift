import Foundation

/// Deterministic, platform-independent RNG (SplitMix64). Every deal is fully
/// reproducible from its seed, which is what makes pre-generated winnable deals,
/// the daily challenge and resume-after-quit possible.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<upperBound` without modulo bias.
    public mutating func next(below upperBound: Int) -> Int {
        precondition(upperBound > 0)
        let bound = UInt64(upperBound)
        let threshold = (0 &- bound) % bound
        while true {
            let value = next()
            if value >= threshold { return Int(value % bound) }
        }
    }
}

public extension Array where Element == Card {
    /// Fisher–Yates shuffle with our own RNG so results never depend on the
    /// standard library's implementation of `shuffle(using:)`.
    static func shuffledDeck(seed: UInt64) -> [Card] {
        var deck = Card.fullDeck
        var rng = SeededRandom(seed: seed)
        var index = deck.count - 1
        while index > 0 {
            let other = rng.next(below: index + 1)
            deck.swapAt(index, other)
            index -= 1
        }
        return deck
    }
}
