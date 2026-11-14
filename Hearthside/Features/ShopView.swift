import SwiftUI
import StoreKit
import GameServices
import HearthsideCore

/// Shop: Remove Ads, Hearthside Club, warmth packs and cosmetics.
/// Offers only appear at natural moments (see `ShopOffer`), never at launch.
struct ShopView: View {
    @Environment(AppModel.self) private var app
    @State private var showClub = false
    @State private var busy: String?
    @State private var message: LocalizedStringKey?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                clubCard
                if !app.adsRemoved {
                    productRow(ProductIDs.removeAds, title: "shop.removeads", subtitle: "shop.removeads.sub", icon: "nosign")
                }
                Text("shop.warmth").font(AppFont.nunito(.title3, weight: .bold)).foregroundStyle(Color.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)
                productRow(ProductIDs.warmthSmall, title: "shop.warmth.small", subtitle: "shop.warmth.amount \(250)", icon: "flame")
                productRow(ProductIDs.warmthMedium, title: "shop.warmth.medium", subtitle: "shop.warmth.amount \(700)", icon: "flame.fill")
                productRow(ProductIDs.warmthLarge, title: "shop.warmth.large", subtitle: "shop.warmth.amount \(1600)", icon: "fireplace")

                Text("shop.cosmetics").font(AppFont.nunito(.title3, weight: .bold)).foregroundStyle(Color.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(CosmeticCategory.allCases, id: \.self) { category in
                    cosmeticSection(category)
                }

                Button("shop.restore") {
                    Task {
                        busy = "restore"
                        await app.purchases.restore()
                        busy = nil
                        message = "shop.restored"
                    }
                }
                .font(AppFont.nunito(.headline, weight: .semibold))
                .foregroundStyle(Color.cream)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(HearthBackground())
        .navigationTitle(Text("shop.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { WarmthBadge(amount: app.progress.village.warmth) } }
        .sheet(isPresented: $showClub) { ClubSubscriptionSheet() }
        .alert(Text(message ?? ""), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private var clubCard: some View {
        Button {
            showClub = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "crown.fill").foregroundStyle(Color.honey)
                    Text("club.title").font(AppFont.nunito(.title2, weight: .heavy))
                    Spacer()
                    if app.isClubMember {
                        Text("club.active").font(AppFont.nunito(.caption, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.pine))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("club.benefit.noads", systemImage: "checkmark")
                    Label("club.benefit.double", systemImage: "checkmark")
                    Label("club.benefit.hints", systemImage: "checkmark")
                    Label("club.benefit.cosmetics", systemImage: "checkmark")
                }
                .font(AppFont.nunito(.subheadline, weight: .semibold))
                if !app.isClubMember {
                    Text("club.trial").font(AppFont.nunito(.headline, weight: .bold)).foregroundStyle(Color.honey)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color.hearthRed, Color(hex: 0x8E3A2A)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .foregroundStyle(Color.cream)
        }
        .buttonStyle(.plain)
    }

    private func productRow(_ id: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String) -> some View {
        let product = app.purchases.products.first { $0.id == id }
        return HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).frame(width: 44, height: 44)
                .background(Circle().fill(Color.honey.opacity(0.3)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.nunito(.headline, weight: .bold))
                Text(subtitle).font(AppFont.nunito(.subheadline)).opacity(0.75)
            }
            Spacer()
            Button {
                Task {
                    busy = id
                    let outcome = await app.purchases.purchase(id)
                    busy = nil
                    if case .failed = outcome { message = "shop.failed" }
                    if case .pending = outcome { message = "shop.pending" }
                }
            } label: {
                Group {
                    if busy == id { ProgressView() } else { Text(product?.displayPrice ?? "…") }
                }
                .font(AppFont.nunito(.headline, weight: .bold))
                .frame(minWidth: 80, minHeight: 44)
                .padding(.horizontal, 8)
                .background(Capsule().fill(Color.hearthRed))
                .foregroundStyle(Color.cream)
            }
            .disabled(product == nil || busy != nil)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cream))
        .foregroundStyle(Color.ink)
    }

    private func price(for productID: String) -> String {
        app.purchases.products.first(where: { $0.id == productID })?.displayPrice ?? "…"
    }

    private func cosmeticSection(_ category: CosmeticCategory) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey("cosmetic.category." + category.rawValue)).font(AppFont.nunito(.headline, weight: .bold))
                ForEach(CosmeticCatalog.all.filter { $0.category == category }) { item in
                    cosmeticRow(item)
                }
            }
        }
    }

    private func cosmeticRow(_ item: CosmeticItem) -> some View {
        let available = app.progress.cosmetics.isAvailable(item, isClubMember: app.isClubMember)
        let selected = app.progress.cosmetics.selected[item.category] == item.id
        return HStack {
            Text(LocalizedStringKey(item.nameKey)).font(AppFont.nunito(.body, weight: .semibold))
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.pine)
            } else if available {
                Button("shop.use") { app.select(item) }.buttonStyle(.bordered).tint(Color.pine)
            } else {
                switch item.unlock {
                case .warmth(let cost):
                    Button {
                        if !app.unlockWithWarmth(item) { message = "shop.notenough" }
                    } label: {
                        Label("\(cost)", systemImage: "flame.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(Color.hearthRed)
                case .club:
                    Button("shop.clubonly") { showClub = true }.buttonStyle(.bordered).tint(Color.honey)
                case .purchase(let productID):
                    Button(price(for: productID)) {
                        Task { _ = await app.purchases.purchase(productID) }
                    }
                    .buttonStyle(.borderedProminent)
                case .free:
                    EmptyView()
                }
            }
        }
    }
}

/// Apple's subscription UI handles prices, trial terms and legal text correctly.
struct ClubSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: [ProductIDs.clubMonthly, ProductIDs.clubYearly]) {
            VStack(spacing: 10) {
                Image(systemName: "crown.fill").font(.system(size: 48)).foregroundStyle(Color.honey)
                Text("club.title").font(AppFont.nunito(.largeTitle, weight: .heavy))
                Text("club.pitch").font(AppFont.nunito(.body)).multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.cream)
            .padding()
        }
        .subscriptionStoreControlStyle(.picker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: Links.privacy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: Links.terms, for: .termsOfService)
        .containerBackground(Color.eveningBlue.gradient, for: .subscriptionStoreFullHeight)
        .tint(Color.hearthRed)
        .onInAppPurchaseCompletion { _, _ in dismiss() }
    }
}

/// Offer card shown at natural moments: low on warmth for a measure, or after the first house.
struct OfferSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let offer: ShopOffer

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: offer == .starterPack ? "gift.fill" : "flame.fill")
                .font(.system(size: 54)).foregroundStyle(Color.hearthRed)
            Text(LocalizedStringKey(offer == .starterPack ? "offer.starter.title" : "offer.low.title"))
                .font(AppFont.nunito(.title2, weight: .bold))
            Text(LocalizedStringKey(offer == .starterPack ? "offer.starter.body" : "offer.low.body"))
                .font(AppFont.nunito(.body)).multilineTextAlignment(.center)
            let id = offer == .starterPack ? ProductIDs.starterPack : ProductIDs.warmthSmall
            Button {
                Task { _ = await app.purchases.purchase(id); dismiss() }
            } label: {
                Text(app.purchases.products.first { $0.id == id }?.displayPrice ?? "…")
            }
            .buttonStyle(HearthButtonStyle())
            Button("offer.later") { dismiss() }
                .font(AppFont.nunito(.headline, weight: .semibold))
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .background(Color.cream.ignoresSafeArea())
        .foregroundStyle(Color.ink)
        .onAppear { app.analytics.log("offer_shown", ["offer": offer.rawValue]) }
    }
}
