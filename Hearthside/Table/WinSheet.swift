import SwiftUI
import HearthsideCore

/// Warm, unhurried win screen: warmth earned, optional rewarded "double warmth",
/// and a clear "Next game". The interstitial (if any) only comes after tapping Next.
struct WinSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let summary: WinSummary
    let game: KlondikeGame
    @State private var doubled = false
    @State private var isWorking = false

    var body: some View {
        ZStack {
            HearthBackground()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient(colors: [.honey, .hearthRed], startPoint: .top, endPoint: .bottom))
                        .symbolEffect(.bounce, value: doubled)
                        .padding(.top, 30)
                    Text("win.title")
                        .font(AppFont.nunito(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.cream)

                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            row("win.base", summary.reward.base)
                            if summary.reward.noHints > 0 { row("win.nohints", summary.reward.noHints) }
                            if summary.reward.fast > 0 { row("win.fast", summary.reward.fast) }
                            if summary.reward.efficient > 0 { row("win.efficient", summary.reward.efficient) }
                            if summary.reward.difficulty > 0 { row("win.difficulty", summary.reward.difficulty) }
                            if summary.reward.drawThree > 0 { row("win.drawthree", summary.reward.drawThree) }
                            if summary.reward.daily > 0 { row("win.daily", summary.reward.daily) }
                            if summary.reward.multiplier > 1 {
                                HStack { Text("win.club"); Spacer(); Text("×\(summary.reward.multiplier)").bold() }
                            }
                            Divider()
                            HStack {
                                Text("win.total").font(AppFont.nunito(.title3, weight: .bold))
                                Spacer()
                                Label("\(summary.warmthEarned * (doubled ? 2 : 1))", systemImage: "flame.fill")
                                    .font(AppFont.nunito(.title2, weight: .bold))
                                    .foregroundStyle(Color.hearthRed)
                                    .contentTransition(.numericText())
                            }
                        }
                        .font(AppFont.nunito(.body))
                    }

                    HStack(spacing: 12) {
                        statTile("hud.time", Text(Duration.seconds(game.elapsed), format: .time(pattern: .minuteSecond)),
                                 highlight: summary.newBestTime)
                        statTile("hud.moves", Text(game.moveCount, format: .number), highlight: summary.newFewestMoves)
                        statTile("win.streak", Text(summary.winStreak, format: .number), highlight: false)
                    }

                    if let decoration = summary.monthDecoration {
                        Panel {
                            Label { Text("win.decoration \(String(localized: String.LocalizationValue(decoration.nameKey)))") }
                                icon: { Image(systemName: "gift.fill").foregroundStyle(Color.hearthRed) }
                        }
                    }

                    if !doubled && app.ads.rewardedAvailable {
                        Button {
                            isWorking = true
                            Task {
                                doubled = await app.doubleWarmth(summary)
                                isWorking = false
                            }
                        } label: {
                            Label("win.double", systemImage: "play.rectangle.fill")
                        }
                        .buttonStyle(HearthButtonStyle(color: .honey, foreground: .ink))
                        .disabled(isWorking)
                    }

                    Button {
                        dismiss()
                        Task { await app.continueAfterWin() }
                    } label: {
                        Text("win.next")
                    }
                    .buttonStyle(HearthButtonStyle())

                    Button("win.village") {
                        dismiss()
                        Task {
                            await app.ads.roundDidEnd()
                            app.path = [.village]
                        }
                    }
                    .font(AppFont.nunito(.headline, weight: .semibold))
                    .foregroundStyle(Color.cream)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, _ amount: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("+\(amount)").bold().monospacedDigit()
        }
    }

    private func statTile(_ title: LocalizedStringKey, _ value: Text, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title).font(AppFont.nunito(.caption, weight: .semibold)).opacity(0.8)
            value.font(AppFont.nunito(.title3, weight: .bold)).monospacedDigit()
            if highlight {
                Text("win.record").font(AppFont.nunito(.caption2, weight: .bold)).foregroundStyle(Color.honey)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.25)))
        .foregroundStyle(Color.cream)
    }
}
