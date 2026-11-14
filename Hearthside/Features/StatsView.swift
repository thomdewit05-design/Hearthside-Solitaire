import SwiftUI
import HearthsideCore

struct StatsView: View {
    @Environment(AppModel.self) private var app
    @State private var drawCount = 1

    var body: some View {
        let stats = app.progress.stats(drawCount: drawCount)
        ScrollView {
            VStack(spacing: 16) {
                Picker("stats.mode", selection: $drawCount) {
                    Text("settings.draw1").tag(1)
                    Text("settings.draw3").tag(3)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    tile("stats.played", Text(stats.gamesPlayed, format: .number))
                    tile("stats.won", Text(stats.gamesWon, format: .number))
                    tile("stats.winrate", Text(stats.winRate, format: .percent.precision(.fractionLength(0))))
                    tile("stats.streak", Text(stats.currentWinStreak, format: .number))
                    tile("stats.longest", Text(stats.longestWinStreak, format: .number))
                    tile("stats.besttime", stats.bestTime.map { Text(Duration.seconds($0), format: .time(pattern: .minuteSecond)) } ?? Text("–"))
                    tile("stats.fewest", stats.fewestMoves.map { Text($0, format: .number) } ?? Text("–"))
                    tile("stats.bestscore", stats.bestScore.map { Text($0, format: .number) } ?? Text("–"))
                }

                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Label { Text("stats.lifetimewarmth \(app.progress.village.lifetimeWarmth)") } icon: {
                            Image(systemName: "flame.fill").foregroundStyle(Color.hearthRed)
                        }
                        Label { Text("stats.houses \(app.progress.village.completedHouseCount)") } icon: {
                            Image(systemName: "house.fill").foregroundStyle(Color.pine)
                        }
                        Label { Text("stats.dailies \(app.progress.daily.completed.count)") } icon: {
                            Image(systemName: "calendar").foregroundStyle(Color.wood)
                        }
                    }
                    .font(AppFont.nunito(.body, weight: .semibold))
                }

                if app.gameCenter.isAuthenticated {
                    Button {
                        app.gameCenter.showDashboard()
                    } label: {
                        Label("stats.gamecenter", systemImage: "trophy.fill")
                    }
                    .buttonStyle(HearthButtonStyle(color: .eveningBlue))
                }
            }
            .padding(16)
        }
        .background(HearthBackground())
        .navigationTitle(Text("stats.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { drawCount = app.settings.drawCount }
    }

    private func tile(_ title: LocalizedStringKey, _ value: Text) -> some View {
        VStack(spacing: 6) {
            Text(title).font(AppFont.nunito(.subheadline, weight: .semibold)).opacity(0.8)
            value.font(AppFont.nunito(.title, weight: .bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.cream))
        .foregroundStyle(Color.ink)
        .accessibilityElement(children: .combine)
    }
}
