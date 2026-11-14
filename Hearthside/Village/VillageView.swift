import SwiftUI
import HearthsideCore

struct EnergyLabelBadge: View {
    let label: EnergyLabel
    var large = false

    var body: some View {
        Text(label.title)
            .font(AppFont.nunito(large ? .title2 : .subheadline, weight: .heavy))
            .foregroundStyle((EnergyLabel.e...EnergyLabel.c).contains(label) ? Color.ink : .white)
            .padding(.horizontal, large ? 14 : 8)
            .padding(.vertical, large ? 6 : 3)
            .background(
                ArrowTag()
                    .fill(Color(hex: label.colorHex))
            )
            .accessibilityLabel(Text("a11y.label \(label.title)"))
    }
}

/// Energy-label style arrow tag.
private struct ArrowTag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = rect.height * 0.35
        path.move(to: CGPoint(x: rect.minX + 3, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 3, y: rect.minY), control: CGPoint(x: rect.minX - 1, y: rect.midY))
        return path
    }
}

/// The village: an isometric-ish grid of eight houses on an evening hillside
/// that warms from cold blue to golden as the player retrofits.
struct VillageView: View {
    @Environment(AppModel.self) private var app

    private let catalog = VillageCatalog.season1

    var body: some View {
        let village = app.progress.village
        let warmth = village.villageWarmth()
        ScrollView {
            VStack(spacing: 18) {
                header(village: village)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(catalog) { house in
                        houseTile(house, village: village)
                    }
                }
                if !app.progress.decorations.isEmpty {
                    decorations
                }
            }
            .padding(16)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x1B2338).blended(with: Color(hex: 0x4A3A5C), amount: warmth),
                                    Color.eveningBlue.blended(with: Color(hex: 0xB86B45), amount: warmth * 0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle(Text("village.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { WarmthBadge(amount: village.warmth) }
        }
        .safeAreaInset(edge: .bottom) {
            if app.ads.bannerAllowed(onGameTable: false) {
                BannerAdView().frame(height: 50)
            }
        }
    }

    private func header(village: VillageState) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                Text("village.subtitle").font(AppFont.nunito(.headline, weight: .bold))
                ProgressView(value: village.villageWarmth())
                    .tint(Color.hearthRed)
                Text("village.progress \(village.completedHouseCount) \(catalog.count)")
                    .font(AppFont.nunito(.subheadline))
                if let goal = village.nextGoal() {
                    HStack {
                        Image(systemName: "target")
                        Text("village.nextgoal \(String(localized: String.LocalizationValue(goal.measure.kind.nameKey))) \(goal.measure.cost)")
                    }
                    .font(AppFont.nunito(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.pine)
                }
            }
        }
    }

    private func houseTile(_ house: HouseBlueprint, village: VillageState) -> some View {
        let progress = village.progress(house.id)
        let label = progress.label(for: house)
        let unlocked = village.isUnlocked(house.id)
        return Button {
            app.path.append(.house(house.id))
        } label: {
            VStack(spacing: 6) {
                HouseIllustration(houseID: house.id, label: label, visuals: progress.visuals(for: house), locked: !unlocked)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        if unlocked { EnergyLabelBadge(label: label) } else {
                            Image(systemName: "lock.fill").foregroundStyle(Color.cream).padding(6)
                        }
                    }
                Text(LocalizedStringKey(house.nameKey))
                    .font(AppFont.nunito(.headline, weight: .bold))
                    .foregroundStyle(Color.cream)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                if unlocked {
                    Text("village.measures \(progress.completed.count) \(house.measures.count)")
                        .font(AppFont.nunito(.caption, weight: .semibold))
                        .foregroundStyle(Color.cream.opacity(0.8))
                } else {
                    Text("village.locked").font(AppFont.nunito(.caption)).foregroundStyle(Color.cream.opacity(0.7))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.22)))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(house.nameKey)))
        .accessibilityValue(unlocked ? Text("a11y.label \(label.title)") : Text("village.locked"))
    }

    private var decorations: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                Text("village.decorations").font(AppFont.nunito(.headline, weight: .bold))
                ForEach(Array(app.progress.decorations.enumerated()), id: \.offset) { _, decoration in
                    Label(LocalizedStringKey(decoration.nameKey), systemImage: "sparkles")
                }
            }
        }
    }
}

private extension Color {
    func blended(with other: Color, amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }
}
