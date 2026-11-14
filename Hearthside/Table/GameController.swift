import Foundation
import Observation
import SpriteKit
import HearthsideCore

/// Owns one Klondike game and connects it to the SpriteKit scene, sounds, haptics,
/// saving and the win flow. All rules live in HearthsideCore.
@MainActor
@Observable
final class GameController {
    private(set) var game: KlondikeGame
    private(set) var accessibilityItems: [AccessibleCard] = []
    private(set) var isComputingHint = false
    private(set) var isAutoCompleting = false
    var winSummary: WinSummary? = nil
    var noHintFound = false

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private weak var app: AppModel?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var lastSave = Date.distantPast

    init(game: KlondikeGame, app: AppModel) {
        self.game = game
        self.app = app
        scene = GameScene(size: CGSize(width: 390, height: 700))
        scene.gameDelegate = self
        scene.sync(game.state, drawCount: game.rules.drawCount, animated: false, canDraw: game.state.canDraw(rules: game.rules))
    }

    // MARK: - Derived state for the HUD

    var score: Int { game.score }
    var moves: Int { game.moveCount }
    var elapsed: TimeInterval { game.elapsed }
    var canUndo: Bool { game.canUndo && !isAutoCompleting && winSummary == nil }
    var canAutoComplete: Bool { game.canAutoComplete && !isAutoCompleting && (app?.settings.autoCompleteEnabled ?? true) }

    var freeHintsLeft: Int {
        guard let app else { return 0 }
        if app.isClubMember { return .max }
        return max(0, app.config.value(ConfigKeys.freeHintsPerGame) - game.hintsUsed)
    }

    // MARK: - Lifecycle

    func appear(appearance: TableAppearance) {
        scene.configure(appearance: appearance)
        refreshScene(animated: false)
        startTimer()
    }

    func disappear() {
        timerTask?.cancel()
        timerTask = nil
        app?.saveActiveGame()
    }

    /// Counts active play time only while the table is visible and the game has started.
    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if self.game.hasStarted && !self.game.isWon && self.winSummary == nil {
                    self.game.elapsed += 1
                }
            }
        }
    }

    // MARK: - Moves

    private func refreshScene(animated: Bool) {
        scene.sync(game.state, drawCount: game.rules.drawCount, animated: animated,
                   canDraw: game.state.canDraw(rules: game.rules))
    }

    @discardableResult
    func perform(_ move: Move, animated: Bool = true) -> Bool {
        guard winSummary == nil, let outcome = try? game.perform(move) else { return false }
        refreshScene(animated: animated)
        feedback(for: move, outcome: outcome)
        persistSoon()
        if game.isWon { handleWin() }
        return true
    }

    private func feedback(for move: Move, outcome: MoveOutcome) {
        guard let app else { return }
        switch move {
        case .draw:
            app.sound.play(outcome.recycled ? .shuffle : .flip)
        case .wasteToFoundation, .tableauToFoundation:
            app.sound.play(.foundation)
            app.haptics.cardPlaced(strong: true)
        default:
            app.sound.play(.place)
            app.haptics.cardPlaced(strong: false)
        }
        if outcome.revealedCard { app.sound.play(.flip) }
    }

    private func persistSoon() {
        guard Date().timeIntervalSince(lastSave) > 2 else { return }
        lastSave = Date()
        app?.saveActiveGame()
    }

    func undo() {
        guard canUndo, game.undo() else { return }
        refreshScene(animated: true)
        app?.sound.play(.place)
        persistSoon()
    }

    // MARK: - Hints

    func requestHint() {
        guard !isComputingHint, winSummary == nil, let app else { return }
        guard freeHintsLeft > 0 else { return }
        startHint(app: app)
    }

    /// Extra hint after the free ones: one rewarded ad.
    func requestHintWithAd() async {
        guard let app, await app.ads.showRewarded(placement: "extra_hint") else { return }
        startHint(app: app)
    }

    private func startHint(app: AppModel) {
        isComputingHint = true
        let state = game.state
        let rules = game.rules
        Task {
            // The solver runs off the main thread; a hint is always a move from a proven win.
            let solved = await Task.detached(priority: .userInitiated) {
                KlondikeSolver(rules: rules, nodeBudget: 200_000).hint(for: state)
            }.value
            self.isComputingHint = false
            guard state == self.game.state else { return } // player moved meanwhile
            let move = solved ?? Self.fallbackHint(state: state, rules: rules)
            guard let move else {
                self.noHintFound = true
                return
            }
            self.game.registerHint()
            self.scene.showHint(move)
            app.analytics.log("hint_used", ["proven": solved == nil ? "no" : "yes"])
        }
    }

    /// When no win can be proven (random deals), still point at a sensible move.
    nonisolated static func fallbackHint(state: KlondikeState, rules: KlondikeRules) -> Move? {
        let moves = state.legalMoves(rules: rules)
        func reveals(_ move: Move) -> Bool {
            if case let .tableauToTableau(from, count, _) = move {
                return state.tableau[from].faceDownCount > 0 && count == state.tableau[from].faceUpCount
            }
            return false
        }
        return moves.first(where: \.isFoundationMove)
            ?? moves.first(where: reveals)
            ?? moves.first(where: { if case .wasteToTableau = $0 { return true } else { return false } })
            ?? moves.first(where: { $0 == .draw })
    }

    // MARK: - Auto-complete

    func autoComplete() {
        guard canAutoComplete else { return }
        let moves = game.autoCompleteMoves()
        guard !moves.isEmpty else { return }
        isAutoCompleting = true
        Task {
            for move in moves {
                guard self.perform(move) else { break }
                try? await Task.sleep(for: .milliseconds(move == .draw ? 60 : 110))
            }
            self.isAutoCompleting = false
        }
    }

    // MARK: - Win

    private func handleWin() {
        guard let app else { return }
        app.sound.play(.win)
        app.haptics.success()
        scene.celebrate()
        let summary = app.didWin(game)
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            self.winSummary = summary
        }
    }
}

extension GameController: GameSceneDelegate {
    func sceneDidTapStock() {
        if !perform(.draw) { app?.haptics.denied() }
    }

    func sceneDidTap(_ location: CardLocation) {
        guard !isAutoCompleting else { return }
        if let move = game.bestMove(forTapAt: location) {
            perform(move)
        } else {
            scene.shake(location)
            app?.haptics.denied()
        }
    }

    func sceneDidDrop(_ location: CardLocation, on target: PileTarget) -> Bool {
        guard !isAutoCompleting, let move = game.move(from: location, to: target) else {
            app?.haptics.denied()
            return false
        }
        return perform(move)
    }

    func sceneLayoutDidChange(_ items: [AccessibleCard]) {
        if items != accessibilityItems { accessibilityItems = items }
    }
}
