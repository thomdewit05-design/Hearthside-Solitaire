import GameKit
import Observation
import UIKit

/// Game Center: achievements and the daily-challenge leaderboard (fastest time).
@MainActor
@Observable
final class GameCenterService {
    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            guard let service = self else { return }
            Task { @MainActor in
                if let viewController, let root = GameCenterService.rootViewController {
                    root.present(viewController, animated: true)
                }
                service.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    func unlock(_ achievementID: String) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    /// Leaderboard score in hundredths of a second (lower is better; configure as "low to high").
    func submitDailyTime(_ seconds: TimeInterval) {
        guard isAuthenticated else { return }
        let score = Int(seconds * 100)
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [GameCenterIDs.dailyLeaderboard]) { _ in }
    }

    func showDashboard() {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.trigger(state: .dashboard) {}
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
    }
}
