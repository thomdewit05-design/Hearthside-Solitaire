import Foundation

/// Generates solver-verified winnable deals and sorts them into easy / normal / hard
/// by search effort (tertiles of `difficultyScore`), so each pool is roughly a third.
public struct DealGenerator: Sendable {
    public struct Report: Sendable {
        public var library: DealLibrary
        public var deals: [VerifiedDeal]
        public var attempted: Int
        public var winnable: Int
        public var unknown: Int
        public var unwinnable: Int
        public var totalSeconds: Double
        public var averageMilliseconds: Double
        public var maxMilliseconds: Double
    }

    public let rules: KlondikeRules
    public let nodeBudget: Int

    public init(rules: KlondikeRules, nodeBudget: Int = 150_000) {
        self.rules = rules
        self.nodeBudget = nodeBudget
    }

    /// Tries consecutive seeds starting at `firstSeed` until `count` winnable deals are found.
    public func generate(count: Int,
                         firstSeed: UInt64 = 1,
                         maxAttempts: Int? = nil,
                         progress: ((Int, Int) -> Void)? = nil) -> Report {
        let solver = KlondikeSolver(rules: rules, nodeBudget: nodeBudget)
        var scored: [(seed: UInt64, result: KlondikeSolver.Result)] = []
        var attempted = 0, unknown = 0, unwinnable = 0
        var totalSeconds = 0.0, maxSeconds = 0.0
        var seed = firstSeed
        let limit = maxAttempts ?? count * 20
        while scored.count < count && attempted < limit {
            let result = solver.solve(.deal(seed: seed))
            attempted += 1
            totalSeconds += result.seconds
            maxSeconds = max(maxSeconds, result.seconds)
            switch result.verdict {
            case .winnable: scored.append((seed, result))
            case .unknown: unknown += 1
            case .unwinnable: unwinnable += 1
            }
            progress?(scored.count, attempted)
            seed += 1
        }

        let sortedScores = scored.map { $0.result.difficultyScore }.sorted()
        let lowCut = Self.quantile(sortedScores, 1.0 / 3.0)
        let highCut = Self.quantile(sortedScores, 2.0 / 3.0)
        var library = DealLibrary(drawCount: rules.drawCount)
        var deals: [VerifiedDeal] = []
        for entry in scored {
            let score = entry.result.difficultyScore
            let difficulty: DealDifficulty = score <= lowCut ? .easy : (score <= highCut ? .normal : .hard)
            deals.append(VerifiedDeal(seed: entry.seed, difficulty: difficulty,
                                      solutionLength: entry.result.solution.count,
                                      nodes: entry.result.nodesExplored))
            switch difficulty {
            case .easy: library.easy.append(entry.seed)
            case .normal: library.normal.append(entry.seed)
            case .hard: library.hard.append(entry.seed)
            }
        }
        return Report(library: library, deals: deals, attempted: attempted, winnable: scored.count,
                      unknown: unknown, unwinnable: unwinnable, totalSeconds: totalSeconds,
                      averageMilliseconds: attempted == 0 ? 0 : totalSeconds / Double(attempted) * 1000,
                      maxMilliseconds: maxSeconds * 1000)
    }

    static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count) * q).rounded(.down))))
        return sorted[index]
    }
}
