import SwiftUI
import HearthsideCore

/// One house: big illustration, current label, and the list of measures to buy.
/// Explains the smart order gently (first insulate, then heat pump) — never a lecture.
struct HouseDetailView: View {
    @Environment(AppModel.self) private var app
    let houseID: String
    @State private var lastReceipt: PurchaseReceipt?
    @State private var errorMessage: LocalizedStringKey?
    @State private var tipFor: MeasureKind?

    private var house: HouseBlueprint? { VillageCatalog.season1.first { $0.id == houseID } }

    var body: some View {
        if let house {
            content(house)
        } else {
            Text("village.unknown")
        }
    }

    private func content(_ house: HouseBlueprint) -> some View {
        let village = app.progress.village
        let progress = village.progress(house.id)
        let label = progress.label(for: house)
        let unlocked = village.isUnlocked(house.id)

        return ScrollView {
            VStack(spacing: 16) {
                HouseIllustration(houseID: house.id, label: label, visuals: progress.visuals(for: house), locked: !unlocked)
                    .frame(maxWidth: 320)
                    .animation(.easeInOut(duration: 0.8), value: label)
                HStack {
                    EnergyLabelBadge(label: label, large: true)
                    Image(systemName: "arrow.right").foregroundStyle(Color.cream.opacity(0.6))
                    EnergyLabelBadge(label: house.maxLabel, large: false).opacity(0.6)
                }
                Text(LocalizedStringKey(house.storyKey))
                    .font(AppFont.nunito(.body))
                    .foregroundStyle(Color.cream.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if !unlocked {
                    Panel { Label("house.locked.hint", systemImage: "lock.fill") }
                }

                if let receipt = lastReceipt {
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("house.upgraded \(receipt.labelBefore.title) \(receipt.labelAfter.title)")
                                .font(AppFont.nunito(.headline, weight: .bold))
                            if receipt.smartOrder && receipt.refund > 0 {
                                Label { Text("house.smartbonus \(receipt.refund)") } icon: {
                                    Image(systemName: "leaf.fill").foregroundStyle(Color.pine)
                                }
                            } else if !receipt.smartOrder {
                                Label("house.ordertip", systemImage: "lightbulb")
                                    .foregroundStyle(Color.wood)
                            }
                            if receipt.houseCompleted {
                                Label("house.completed", systemImage: "house.fill").foregroundStyle(Color.hearthRed)
                            }
                        }
                        .font(AppFont.nunito(.subheadline))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 10) {
                    ForEach(house.measures) { measure in
                        measureRow(measure, house: house, progress: progress, village: village, unlocked: unlocked)
                    }
                }
            }
            .padding(16)
        }
        .background(HearthBackground())
        .navigationTitle(Text(LocalizedStringKey(house.nameKey)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { WarmthBadge(amount: village.warmth) } }
        .alert(Text(errorMessage ?? ""), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) {}
            Button("village.playmore") { app.playClassic() }
        }
        .sheet(item: $tipFor) { kind in
            MeasureInfoSheet(kind: kind)
                .presentationDetents([.medium])
        }
    }

    private func measureRow(_ measure: Measure, house: HouseBlueprint, progress: HouseProgress,
                            village: VillageState, unlocked: Bool) -> some View {
        let done = progress.completed.contains(measure.kind)
        let smart = village.isSmartOrder(measure.kind, in: house)
        let affordable = village.warmth >= measure.cost
        return HStack(spacing: 12) {
            Image(systemName: icon(for: measure.kind))
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(done ? Color.pine : Color.wood.opacity(0.25)))
                .foregroundStyle(done ? Color.cream : Color.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(measure.kind.nameKey)).font(AppFont.nunito(.headline, weight: .bold))
                if !done && smart {
                    Text("house.smartbadge").font(AppFont.nunito(.caption, weight: .semibold)).foregroundStyle(Color.pine)
                }
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Color.pine)
                    .accessibilityLabel(Text("house.done"))
            } else {
                Button {
                    buy(measure.kind)
                } label: {
                    Label("\(measure.cost)", systemImage: "flame.fill")
                        .font(AppFont.nunito(.headline, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Capsule().fill(affordable ? Color.hearthRed : Color.gray.opacity(0.5)))
                        .foregroundStyle(Color.cream)
                }
                .disabled(!unlocked)
                .accessibilityLabel(Text("house.buy \(String(localized: String.LocalizationValue(measure.kind.nameKey))) \(measure.cost)"))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cream))
        .foregroundStyle(Color.ink)
        .contentShape(Rectangle())
        .onTapGesture { tipFor = measure.kind }
    }

    private func buy(_ kind: MeasureKind) {
        switch app.buy(kind, in: houseID) {
        case .success(let receipt):
            withAnimation(.spring) { lastReceipt = receipt }
        case .failure(.notEnoughWarmth(let missing)):
            errorMessage = "house.notenough \(missing)"
        case .failure(.houseLocked):
            errorMessage = "house.locked.hint"
        case .failure:
            errorMessage = "house.error"
        }
    }

    private func icon(for kind: MeasureKind) -> String {
        switch kind {
        case .draughtProofing: return "wind"
        case .roofInsulation, .atticFloorInsulation: return "house.lodge"
        case .cavityWallInsulation, .interiorWallInsulation: return "square.stack.3d.up"
        case .floorInsulation: return "square.split.bottomrightquarter"
        case .hrGlazing, .tripleGlazing: return "window.casement"
        case .insulatedDoors: return "door.left.hand.closed"
        case .balancedVentilation, .demandVentilation: return "fan"
        case .hybridHeatPump, .heatPump: return "heat.waves"
        case .solarWaterHeater: return "drop.degreesign"
        case .solarPanels: return "sun.max.fill"
        }
    }
}

extension MeasureKind: @retroactive Identifiable {
    public var id: String { rawValue }
}

/// Short, friendly explanation of a measure (tap on a row).
private struct MeasureInfoSheet: View {
    let kind: MeasureKind

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey(kind.nameKey)).font(AppFont.nunito(.title2, weight: .bold))
            Text(LocalizedStringKey(kind.tipKey)).font(AppFont.nunito(.body))
            Label {
                Text(LocalizedStringKey("phase." + String(kind.phase.rawValue)))
            } icon: {
                Image(systemName: "list.number")
            }
            .font(AppFont.nunito(.subheadline, weight: .semibold))
            .foregroundStyle(Color.pine)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cream.ignoresSafeArea())
        .foregroundStyle(Color.ink)
    }
}
