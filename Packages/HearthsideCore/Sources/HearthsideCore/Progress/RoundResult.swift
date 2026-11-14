import Foundation

/// Everything the win screen needs after a round.
public struct WinSummary: Codable, Hashable, Sendable {
    public var reward: WinReward
    public var warmthEarned: Int
    public var newBestTime: Bool
    public var newFewestMoves: Bool
    public var winStreak: Int
    public var dailyCompleted: DayKey?
    public var monthDecoration: Decoration?
}

public extension PlayerProgress {
    func stats(drawCount: Int) -> GameStatistics {
        drawCount == 3 ? statsDrawThree : statsDrawOne
    }

    private mutating func updateStats(drawCount: Int, _ change: (inout GameStatistics) -> Void) {
        if drawCount == 3 { change(&statsDrawThree) } else { change(&statsDrawOne) }
    }

    /// Records a won game: statistics, warmth, daily calendar and decorations.
    mutating func recordWin(_ game: KlondikeGame, config: EconomyConfig = .init(), isClubMember: Bool = false) -> WinSummary {
        let before = stats(drawCount: game.rules.drawCount)
        updateStats(drawCount: game.rules.drawCount) {
            $0.recordWin(time: game.elapsed, moves: game.moveCount, score: game.score)
        }
        let after = stats(drawCount: game.rules.drawCount)
        let reward = WarmthEconomy.reward(for: game, config: config, isClubMember: isClubMember)
        village.earn(reward.total)

        var dailyDay: DayKey?
        var decoration: Decoration?
        if let dateString = game.deal.dailyDate, let day = DayKey(string: dateString) {
            dailyDay = day
            if let month = daily.complete(day) {
                let award = Decoration.forMonth(month)
                decorations.append(award)
                decoration = award
            }
        }
        rememberSeed(game.deal.seed)
        revision += 1
        return WinSummary(reward: reward,
                          warmthEarned: reward.total,
                          newBestTime: before.bestTime.map { game.elapsed < $0 } ?? true,
                          newFewestMoves: before.fewestMoves.map { game.moveCount < $0 } ?? true,
                          winStreak: after.currentWinStreak,
                          dailyCompleted: dailyDay,
                          monthDecoration: decoration)
    }

    /// Records a game that was abandoned after at least one move.
    mutating func recordLoss(_ game: KlondikeGame) {
        updateStats(drawCount: game.rules.drawCount) { $0.recordLoss(time: game.elapsed) }
        rememberSeed(game.deal.seed)
        revision += 1
    }

    /// Doubles the warmth of the last win (rewarded ad). Returns the extra warmth.
    mutating func grantDoubleWarmth(for summary: WinSummary) -> Int {
        village.earn(summary.warmthEarned)
        revision += 1
        return summary.warmthEarned
    }
}
