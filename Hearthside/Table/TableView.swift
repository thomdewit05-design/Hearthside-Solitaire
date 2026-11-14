import SwiftUI
import SpriteKit
import HearthsideCore

/// The game screen: SpriteKit table with a calm SwiftUI HUD and toolbar.
/// No banner ads here — ever (see docs/PLAN.md).
struct TableView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var confirmNewGame = false
    @State private var showHintOffer = false

    var body: some View {
        Group {
            if let controller = app.activeGame {
                content(controller)
            } else {
                ProgressView().onAppear { app.newGame() }
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(Color.woodDark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func content(_ controller: GameController) -> some View {
        VStack(spacing: 0) {
            HUDView(controller: controller, showTimer: app.settings.showTimer)
            ZStack {
                SpriteView(scene: controller.scene, preferredFramesPerSecond: 60,
                           options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                    .accessibilityHidden(voiceOver)
                if voiceOver {
                    AccessibilityOverlay(controller: controller)
                }
                if controller.canAutoComplete {
                    VStack {
                        Spacer()
                        Button {
                            controller.autoComplete()
                        } label: {
                            Label("table.autocomplete", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(HearthButtonStyle(color: .pine))
                        .frame(maxWidth: 280)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut, value: controller.canAutoComplete)
            TableToolbar(controller: controller,
                         onNewGame: { confirmNewGame = controller.game.hasStarted && !controller.game.isWon
                             if !confirmNewGame { app.newGame() } },
                         onHintOffer: { showHintOffer = true })
        }
        .background(Color.woodDark.ignoresSafeArea())
        .onAppear { controller.appear(appearance: appearance) }
        .onDisappear { controller.disappear() }
        .onChange(of: appearance) { _, new in controller.scene.configure(appearance: new) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.appear(appearance: appearance) } else { controller.disappear() }
        }
        .confirmationDialog("table.newgame.confirm", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("table.newgame", role: .destructive) { app.newGame() }
            Button("table.replay") { app.replaySameDeal() }
            Button("common.cancel", role: .cancel) {}
        }
        .alert("hint.extra.title", isPresented: $showHintOffer) {
            if app.ads.rewardedAvailable {
                Button("hint.extra.watch") { Task { await controller.requestHintWithAd() } }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(app.ads.rewardedAvailable ? "hint.extra.message" : "hint.extra.unavailable"))
        }
        .alert("hint.none", isPresented: Binding(get: { controller.noHintFound },
                                                set: { controller.noHintFound = $0 })) {
            Button("common.ok", role: .cancel) {}
        }
        .sheet(item: Binding(get: { controller.winSummary.map(WinSheetItem.init) },
                             set: { if $0 == nil { controller.winSummary = nil } })) { item in
            WinSheet(summary: item.summary, game: controller.game)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        .id(ObjectIdentifier(controller))
    }

    private var appearance: TableAppearance {
        TableAppearance(cardSize: app.settings.cardSize,
                        highContrast: app.settings.highContrast,
                        leftHanded: app.settings.leftHanded,
                        cardBack: app.progress.cosmetics.selected[.cardBack] ?? "back_hearth",
                        table: app.progress.cosmetics.selected[.table] ?? "table_oak",
                        fire: app.progress.cosmetics.selected[.fire] ?? "fire_classic")
    }
}

private struct WinSheetItem: Identifiable {
    let summary: WinSummary
    var id: String { "\(summary.warmthEarned)-\(summary.winStreak)" }
}

private struct HUDView: View {
    let controller: GameController
    let showTimer: Bool

    var body: some View {
        HStack(spacing: 18) {
            stat("hud.score", value: Text(controller.score, format: .number))
            stat("hud.moves", value: Text(controller.moves, format: .number))
            if showTimer {
                stat("hud.time", value: Text(Duration.seconds(controller.elapsed), format: .time(pattern: .minuteSecond)))
            }
            Spacer()
            if let difficulty = controller.game.deal.difficulty {
                Text(LocalizedStringKey("difficulty." + difficulty.rawValue))
                    .font(AppFont.nunito(.subheadline, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.25)))
            }
        }
        .foregroundStyle(Color.cream)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.woodDark)
    }

    private func stat(_ title: LocalizedStringKey, value: Text) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(AppFont.nunito(.caption, weight: .semibold)).opacity(0.75)
            value.font(AppFont.nunito(.title3, weight: .bold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TableToolbar: View {
    let controller: GameController
    let onNewGame: () -> Void
    let onHintOffer: () -> Void

    var body: some View {
        HStack {
            toolbarButton("table.new", systemImage: "rectangle.stack.badge.plus", action: onNewGame)
            toolbarButton("table.undo", systemImage: "arrow.uturn.backward", action: controller.undo)
                .disabled(!controller.canUndo)
            hintButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color.woodDark)
    }

    private var hintButton: some View {
        Button {
            if controller.freeHintsLeft > 0 { controller.requestHint() } else { onHintOffer() }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if controller.isComputingHint {
                        ProgressView().tint(Color.cream)
                    } else {
                        Image(systemName: "lightbulb.fill").font(.title2)
                    }
                }
                .frame(height: 28)
                Text(hintTitle).font(AppFont.nunito(.caption, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .foregroundStyle(Color.cream)
        .accessibilityLabel(Text("table.hint"))
    }

    private var hintTitle: LocalizedStringKey {
        let left = controller.freeHintsLeft
        if left == .max { return "table.hint" }
        return left > 0 ? "table.hint.left \(left)" : "table.hint.more"
    }

    private func toolbarButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage).font(.title2).frame(height: 28)
                Text(title).font(AppFont.nunito(.caption, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .foregroundStyle(Color.cream)
    }
}

/// VoiceOver layer: one element per playable card/pile, activating = tap ("best place").
private struct AccessibilityOverlay: View {
    let controller: GameController

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(controller.accessibilityItems) { item in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: item.frame.width, height: max(item.frame.height, 20))
                    .offset(x: item.frame.minX, y: item.frame.minY)
                    .accessibilityElement()
                    .accessibilityLabel(item.label)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        if case .stock = item.location { controller.sceneDidTapStock() } else { controller.sceneDidTap(item.location) }
                    }
            }
        }
    }
}
