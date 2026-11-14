import XCTest
@testable import HearthsideCore

final class ProgressTests: XCTestCase {
    let today = DayKey(year: 2026, month: 11, day: 14)

    func testDayKeyArithmetic() throws {
        XCTAssertEqual(today.description, "2026-11-14")
        XCTAssertEqual(today.adding(days: 17).description, "2026-12-01")
        XCTAssertEqual(today.adding(days: -14).description, "2026-10-31")
        XCTAssertEqual(today.days(until: today.adding(days: 3)), 3)
        XCTAssertEqual(today.daysInMonth, 30)
        XCTAssertEqual(DayKey(year: 2028, month: 2, day: 1).daysInMonth, 29)
        XCTAssertEqual(today.isoWeekday, 6, "14 Nov 2026 is a Saturday")
        XCTAssertEqual(DayKey(string: "2026-11-14"), today)
        XCTAssertNil(DayKey(string: "nope"))
        let data = try JSONEncoder().encode([today])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-11-14\"]")
        XCTAssertEqual(try JSONDecoder().decode([DayKey].self, from: data), [today])
        XCTAssertLessThan(today, today.adding(days: 1))
    }

    func testDailyRewardStreak() {
        var reward = DailyRewardState()
        XCTAssertEqual(reward.claim(today: today), 10)
        XCTAssertEqual(reward.claim(today: today), 0, "only once per day")
        var day = today
        for expected in DailyRewardState.rewards.dropFirst() {
            day = day.adding(days: 1)
            XCTAssertEqual(reward.claim(today: day), expected)
        }
        // After day 7 it wraps to day 1.
        day = day.adding(days: 1)
        XCTAssertEqual(reward.rewardForToday(day), 10)
        // Missing a day resets.
        _ = reward.claim(today: day)
        _ = reward.claim(today: day.adding(days: 1))
        XCTAssertEqual(reward.nextStreakDay(today: day.adding(days: 3)), 1)
    }

    func testDailyChallengeCalendar() {
        var daily = DailyChallengeState()
        let library = DealLibrary(drawCount: 1, easy: [1], normal: [10, 20, 30, 40], hard: [99])
        let dealA = DailyChallengeState.deal(for: today, library: library)
        let dealB = DailyChallengeState.deal(for: today, library: library)
        XCTAssertEqual(dealA, dealB, "everyone gets the same deal")
        XCTAssertTrue(library.normal.contains(dealA.seed))
        XCTAssertEqual(dealA.dailyDate, "2026-11-14")
        XCTAssertTrue(dealA.winnable)

        XCTAssertTrue(daily.isPlayable(today, today: today))
        XCTAssertFalse(daily.isPlayable(today.adding(days: 1), today: today))
        XCTAssertFalse(daily.isPlayable(DayKey(year: 2026, month: 10, day: 30), today: today))
        XCTAssertTrue(daily.needsCatchUp(DayKey(year: 2026, month: 11, day: 2), today: today))

        var award: String?
        for d in 1...30 {
            award = daily.complete(DayKey(year: 2026, month: 11, day: d)) ?? award
        }
        XCTAssertEqual(award, "2026-11")
        XCTAssertTrue(daily.isMonthComplete(today))
        XCTAssertNil(daily.complete(today), "awarded only once")
        XCTAssertEqual(Decoration.forMonth("2026-12"), .christmasTree)
    }

    func testDailyDealWithoutLibraryFallsBack() {
        let deal = DailyChallengeState.deal(for: today, library: DealLibrary(drawCount: 1))
        XCTAssertFalse(deal.winnable)
        XCTAssertEqual(deal.seed, DailyChallengeState.deal(for: today, library: DealLibrary(drawCount: 1)).seed)
    }

    func testStatistics() {
        var stats = GameStatistics()
        stats.recordWin(time: 200, moves: 120, score: 500)
        stats.recordWin(time: 150, moves: 130, score: 400)
        stats.recordLoss(time: 60)
        stats.recordWin(time: 300, moves: 90, score: 600)
        XCTAssertEqual(stats.gamesPlayed, 4)
        XCTAssertEqual(stats.gamesWon, 3)
        XCTAssertEqual(stats.winRate, 0.75)
        XCTAssertEqual(stats.bestTime, 150)
        XCTAssertEqual(stats.fewestMoves, 90)
        XCTAssertEqual(stats.bestScore, 600)
        XCTAssertEqual(stats.longestWinStreak, 2)
        XCTAssertEqual(stats.currentWinStreak, 1)
        XCTAssertEqual(GameStatistics().winRate, 0)
    }

    func testRecordWinUpdatesEverything() throws {
        var progress = PlayerProgress()
        var game = KlondikeGame(deal: DealInfo(seed: 3, winnable: true, difficulty: .normal, dailyDate: "2026-11-14"),
                                rules: .standard(drawCount: 1))
        game.elapsed = 180
        let summary = progress.recordWin(game)
        XCTAssertEqual(summary.warmthEarned, progress.village.warmth)
        XCTAssertEqual(summary.dailyCompleted, today)
        XCTAssertTrue(summary.newBestTime)
        XCTAssertEqual(summary.winStreak, 1)
        XCTAssertEqual(progress.statsDrawOne.gamesWon, 1)
        XCTAssertTrue(progress.daily.isCompleted(today))
        XCTAssertEqual(progress.recentSeeds, [3])

        let extra = progress.grantDoubleWarmth(for: summary)
        XCTAssertEqual(progress.village.warmth, summary.warmthEarned + extra)

        progress.recordLoss(KlondikeGame(deal: DealInfo(seed: 4, winnable: false), rules: .standard(drawCount: 3)))
        XCTAssertEqual(progress.statsDrawThree.gamesPlayed, 1)
        XCTAssertEqual(progress.totalGamesPlayed, 2)
        XCTAssertEqual(progress.totalGamesWon, 1)
    }

    func testMergeKeepsProgressFromBothDevices() throws {
        var phone = PlayerProgress()
        phone.village.warmth = 10_000
        try phone.village.buy(.draughtProofing, in: "bakery")
        phone.daily.complete(today)
        phone.revision = 5

        var tablet = PlayerProgress()
        tablet.village.warmth = 10_000
        try tablet.village.buy(.roofInsulation, in: "bakery")
        tablet.daily.complete(today.adding(days: -1))
        tablet.cosmetics.owned.insert("back_pine")
        tablet.decorations = [.snowman]
        tablet.revision = 3

        let merged = PlayerProgress.merged(phone, tablet)
        XCTAssertEqual(Set(merged.village.progress("bakery").completed), [.draughtProofing, .roofInsulation])
        XCTAssertEqual(merged.daily.completed.count, 2)
        XCTAssertTrue(merged.cosmetics.owned.contains("back_pine"))
        XCTAssertEqual(merged.decorations, [.snowman])
        XCTAssertEqual(merged.revision, 6)
    }

    func testProgressCodableRoundTrip() throws {
        var progress = PlayerProgress()
        progress.village.earn(99)
        progress.cosmetics.selected[.table] = "table_walnut"
        progress.daily.complete(today)
        let data = try JSONEncoder().encode(progress)
        XCTAssertEqual(try JSONDecoder().decode(PlayerProgress.self, from: data), progress)
    }

    func testRecentSeedsAreCapped() {
        var progress = PlayerProgress()
        for seed in UInt64(0)..<250 { progress.rememberSeed(seed) }
        XCTAssertEqual(progress.recentSeeds.count, 200)
        XCTAssertEqual(progress.recentSeeds.first, 50)
    }

    func testCosmetics() {
        let state = CosmeticsState()
        let free = CosmeticCatalog.all.first { $0.id == "back_hearth" }!
        let club = CosmeticCatalog.all.first { $0.id == "back_starry" }!
        let paid = CosmeticCatalog.all.first { $0.id == "back_pine" }!
        XCTAssertTrue(state.isAvailable(free, isClubMember: false))
        XCTAssertFalse(state.isAvailable(club, isClubMember: false))
        XCTAssertTrue(state.isAvailable(club, isClubMember: true))
        XCTAssertFalse(state.isAvailable(paid, isClubMember: true))
        XCTAssertEqual(state.selected[.fire], "fire_classic")
        XCTAssertEqual(free.nameKey, "cosmetic.back_hearth")
    }
}
