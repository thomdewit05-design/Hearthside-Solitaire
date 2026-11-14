import Foundation

/// One solver-verified deal.
public struct VerifiedDeal: Codable, Hashable, Sendable {
    public var seed: UInt64
    public var difficulty: DealDifficulty
    /// Moves in the solver's solution (a rough measure, not the optimum).
    public var solutionLength: Int
    public var nodes: Int

    public init(seed: UInt64, difficulty: DealDifficulty, solutionLength: Int, nodes: Int) {
        self.seed = seed
        self.difficulty = difficulty
        self.solutionLength = solutionLength
        self.nodes = nodes
    }
}

/// The pre-generated pools of winnable deals shipped in `Resources/deals/`.
/// File format (`klondike-draw1.json` / `klondike-draw3.json`):
/// `{ "drawCount": 1, "easy": [seed, …], "normal": […], "hard": […] }`
public struct DealLibrary: Codable, Sendable, Equatable {
    public var drawCount: Int
    public var easy: [UInt64]
    public var normal: [UInt64]
    public var hard: [UInt64]

    public init(drawCount: Int, easy: [UInt64] = [], normal: [UInt64] = [], hard: [UInt64] = []) {
        self.drawCount = drawCount
        self.easy = easy
        self.normal = normal
        self.hard = hard
    }

    public var totalCount: Int { easy.count + normal.count + hard.count }

    public func seeds(_ difficulty: DealDifficulty) -> [UInt64] {
        switch difficulty {
        case .easy: return easy
        case .normal: return normal
        case .hard: return hard
        }
    }

    public static func load(from data: Data) throws -> DealLibrary {
        try JSONDecoder().decode(DealLibrary.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

/// Picks the next deal for the player according to the plan's difficulty rules:
/// the first 5 games come from the easy pool, after that normal and hard are mixed.
public struct DealPicker: Sendable {
    public var library: DealLibrary
    /// How many games use the easy pool for new players (Remote Config: `newPlayerEasyGames`).
    public var newPlayerEasyGames: Int
    /// Share of hard deals once past the intro (Remote Config: `hardDealShare`).
    public var hardShare: Double

    public init(library: DealLibrary, newPlayerEasyGames: Int = 5, hardShare: Double = 0.35) {
        self.library = library
        self.newPlayerEasyGames = newPlayerEasyGames
        self.hardShare = hardShare
    }

    public func nextDeal<R: RandomNumberGenerator>(gamesPlayed: Int,
                                                   alwaysWinnable: Bool,
                                                   recentSeeds: Set<UInt64> = [],
                                                   using rng: inout R) -> DealInfo {
        guard alwaysWinnable, library.totalCount > 0 else {
            return DealInfo(seed: UInt64.random(in: 1...UInt64(UInt32.max), using: &rng) | (1 << 40),
                            winnable: false)
        }
        let difficulty: DealDifficulty
        if gamesPlayed < newPlayerEasyGames {
            difficulty = .easy
        } else {
            difficulty = Double.random(in: 0..<1, using: &rng) < hardShare ? .hard : .normal
        }
        var pool = library.seeds(difficulty)
        if pool.isEmpty { pool = library.easy + library.normal + library.hard }
        let fresh = pool.filter { !recentSeeds.contains($0) }
        let source = fresh.isEmpty ? pool : fresh
        let seed = source[Int.random(in: 0..<source.count, using: &rng)]
        return DealInfo(seed: seed, winnable: true, difficulty: difficulty)
    }
}
