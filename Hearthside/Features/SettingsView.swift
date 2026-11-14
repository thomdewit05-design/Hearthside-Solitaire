import SwiftUI
import GameServices
import HearthsideCore

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Form {
            Section("settings.game") {
                Picker("settings.draw", selection: app.setting(\.drawCount)) {
                    Text("settings.draw1").tag(1)
                    Text("settings.draw3").tag(3)
                }
                Picker("settings.scoring", selection: app.setting(\.scoring)) {
                    Text("settings.scoring.standard").tag(ScoringMode.standard)
                    Text("settings.scoring.vegas").tag(ScoringMode.vegas)
                }
                Picker("settings.deals", selection: app.setting(\.alwaysWinnable)) {
                    Text("settings.deals.winnable").tag(true)
                    Text("settings.deals.random").tag(false)
                }
                Toggle("settings.autocomplete", isOn: app.setting(\.autoCompleteEnabled))
                Toggle("settings.timer", isOn: app.setting(\.showTimer))
                Text("settings.rules.note").font(.footnote).foregroundStyle(.secondary)
            }

            Section("settings.readability") {
                Picker("settings.cardsize", selection: app.setting(\.cardSize)) {
                    ForEach(CardSize.allCases) { size in Text(LocalizedStringKey(size.titleKey)).tag(size) }
                }
                Toggle("settings.contrast", isOn: app.setting(\.highContrast))
                Toggle("settings.lefthanded", isOn: app.setting(\.leftHanded))
            }

            Section("settings.feedback") {
                Toggle("settings.sound", isOn: app.setting(\.soundEnabled))
                Toggle("settings.haptics", isOn: app.setting(\.hapticsEnabled))
            }

            Section("settings.account") {
                Button("shop.restore") { Task { await app.purchases.restore() } }
                if app.consent.state.privacyOptionsRequired {
                    Button("settings.privacyoptions") { Task { await app.consent.presentPrivacyOptions() } }
                }
                Link("settings.privacy", destination: Links.privacy)
                Link("settings.terms", destination: Links.terms)
                Link("settings.support", destination: Links.support)
            }

            Section {
                Text("settings.about \(Bundle.main.shortVersion)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .font(AppFont.nunito(.body))
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Bundle {
    var shortVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#if DEBUG
/// Debug-only tools: grant warmth, force ads, inspect analytics, override Remote Config.
struct DebugMenuView: View {
    @Environment(AppModel.self) private var app
    @State private var overrideKey = ""
    @State private var overrideValue = ""

    var body: some View {
        Form {
            Section("Economy") {
                Button("+500 warmth") { app.grantWarmth(500, source: "debug") }
                Button("+5000 warmth") { app.grantWarmth(5_000, source: "debug") }
                Button("Reset progress", role: .destructive) { app.debugReset() }
            }
            Section("Ads") {
                LabeledContent("Rounds completed", value: "\(app.ads.ledger.roundsCompleted)")
                LabeledContent("Rewarded left today", value: "\(app.ads.rewardedRemainingToday)")
                Button("Simulate round end") { Task { await app.ads.roundDidEnd(placement: "debug") } }
                Button("Show rewarded") { Task { _ = await app.ads.showRewarded(placement: "debug") } }
            }
            Section("Remote Config override") {
                TextField("key", text: $overrideKey).textInputAutocapitalization(.never)
                TextField("value", text: $overrideValue).textInputAutocapitalization(.never)
                Button("Apply") {
                    app.config.overrides[overrideKey] = overrideValue
                    app.ads.policy = AdPolicy(rules: AppModel.adRules(app.config))
                }
            }
            Section("Last analytics events") {
                ForEach(Array(app.analytics.recent.suffix(30).reversed().enumerated()), id: \.offset) { _, event in
                    VStack(alignment: .leading) {
                        Text(event.0).font(.caption.bold())
                        Text(event.1.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")).font(.caption2)
                    }
                }
            }
            Section("Game") {
                Button("Win current game (auto-solve)") {
                    guard let controller = app.activeGame else { return }
                    let state = controller.game.state
                    let rules = controller.game.rules
                    let result = KlondikeSolver(rules: rules, nodeBudget: 300_000).solve(state)
                    guard result.verdict == .winnable else { return }
                    for move in result.solution { controller.perform(move, animated: false) }
                }
            }
        }
        .navigationTitle("Debug")
    }
}
#endif
