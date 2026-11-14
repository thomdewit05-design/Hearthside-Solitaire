import SwiftUI
import HearthsideCore

/// Home: big, calm buttons. Continue / new game first, then the daily challenge and the village.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showDailyReward = false

    var body: some View {
        ZStack {
            HearthBackground()
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    Button {
                        app.playClassic()
                    } label: {
                        Label(LocalizedStringKey(canContinue ? "home.continue" : "home.play"),
                              systemImage: "suit.heart.fill")
                    }
                    .buttonStyle(HearthButtonStyle())

                    Button {
                        app.path.append(.daily)
                    } label: {
                        HStack {
                            Label("home.daily", systemImage: "calendar")
                            if !app.progress.daily.isCompleted(app.today) {
                                Circle().fill(Color.honey).frame(width: 10, height: 10)
                            }
                        }
                    }
                    .buttonStyle(HearthButtonStyle(color: .pine))

                    Button {
                        app.path.append(.village)
                    } label: {
                        Label("home.village", systemImage: "house.fill")
                    }
                    .buttonStyle(HearthButtonStyle(color: .wood))

                    HStack(spacing: 12) {
                        smallButton("home.stats", "chart.bar.fill") { app.path.append(.stats) }
                        smallButton("home.shop", "bag.fill") { app.path.append(.shop) }
                        smallButton("home.settings", "gearshape.fill") { app.path.append(.settings) }
                    }

                    if app.canClaimDailyReward {
                        Button {
                            showDailyReward = true
                        } label: {
                            Label("home.dailyreward", systemImage: "gift.fill")
                        }
                        .buttonStyle(HearthButtonStyle(color: .honey, foreground: .ink))
                    }

                    #if DEBUG
                    Button("Debug") { app.path.append(.debug) }
                        .foregroundStyle(Color.cream.opacity(0.5))
                    #endif
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if app.ads.bannerAllowed(onGameTable: false) { BannerAdView().frame(height: 50) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showDailyReward) {
            DailyRewardSheet().presentationDetents([.medium, .large])
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                WarmthBadge(amount: app.progress.village.warmth)
            }
            HouseIllustration(houseID: currentHouse.id,
                              label: app.progress.village.progress(currentHouse.id).label(for: currentHouse),
                              visuals: app.progress.village.progress(currentHouse.id).visuals(for: currentHouse))
                .frame(height: 200)
            Text("Hearthside")
                .font(AppFont.nunito(.largeTitle, weight: .heavy))
                .foregroundStyle(Color.cream)
            Text("home.tagline")
                .font(AppFont.nunito(.headline))
                .foregroundStyle(Color.cream.opacity(0.8))
        }
        .padding(.bottom, 8)
    }

    private var canContinue: Bool {
        guard let game = app.activeGame?.game else { return false }
        return game.hasStarted && game.deal.dailyDate == nil
    }

    /// The house the player is currently working on, for the hero image.
    private var currentHouse: HouseBlueprint {
        app.progress.village.nextGoal()?.house ?? VillageCatalog.season1.last!
    }

    private func smallButton(_ title: LocalizedStringKey, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title).font(AppFont.nunito(.subheadline, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.25)))
            .foregroundStyle(Color.cream)
        }
    }
}

/// 7-day reward with an optional rewarded "x2".
struct DailyRewardSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let today = app.today
        let nextDay = app.progress.dailyReward.nextStreakDay(today: today)
        VStack(spacing: 18) {
            Text("reward.title").font(AppFont.nunito(.title, weight: .bold))
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text("reward.day \(day)").font(AppFont.nunito(.caption2, weight: .semibold))
                        Image(systemName: day < nextDay ? "checkmark.circle.fill" : (day == 7 ? "gift.fill" : "flame.fill"))
                            .foregroundStyle(day == nextDay ? Color.hearthRed : Color.wood)
                        Text("\(DailyRewardState.rewards[day - 1])").font(AppFont.nunito(.caption, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(day == nextDay ? Color.honey.opacity(0.35) : Color.wood.opacity(0.12)))
                }
            }
            Button {
                Task { await app.claimDailyReward(doubled: false); dismiss() }
            } label: {
                Text("reward.claim \(app.progress.dailyReward.rewardForToday(today))")
            }
            .buttonStyle(HearthButtonStyle())
            if app.ads.rewardedAvailable {
                Button {
                    Task { await app.claimDailyReward(doubled: true); dismiss() }
                } label: {
                    Label("reward.double", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(HearthButtonStyle(color: .honey, foreground: .ink))
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .background(Color.cream.ignoresSafeArea())
        .foregroundStyle(Color.ink)
    }
}
