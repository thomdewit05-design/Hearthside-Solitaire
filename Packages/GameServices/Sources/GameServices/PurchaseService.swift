import Foundation

public enum ProductKind: String, Sendable, Codable {
    case removeAds        // non-consumable
    case subscription     // auto-renewable (Club / VIP)
    case consumable       // currency packs
    case nonConsumable    // cosmetics, starter pack
}

public struct ProductDefinition: Sendable, Hashable {
    public var id: String
    public var kind: ProductKind
    /// Amount of in-game currency for consumables.
    public var currencyAmount: Int

    public init(id: String, kind: ProductKind, currencyAmount: Int = 0) {
        self.id = id
        self.kind = kind
        self.currencyAmount = currencyAmount
    }
}

/// What the player is entitled to right now. Pure value, derived from transactions.
public struct Entitlements: Codable, Hashable, Sendable {
    public var ownedNonConsumables: Set<String> = []
    public var activeSubscription: String?
    public var subscriptionExpires: Date?

    public init(ownedNonConsumables: Set<String> = [], activeSubscription: String? = nil, subscriptionExpires: Date? = nil) {
        self.ownedNonConsumables = ownedNonConsumables
        self.activeSubscription = activeSubscription
        self.subscriptionExpires = subscriptionExpires
    }

    public func isSubscriber(at date: Date = Date()) -> Bool {
        guard activeSubscription != nil else { return false }
        guard let expires = subscriptionExpires else { return true }
        return expires > date
    }

    /// Remove Ads purchase or an active subscription both remove interstitials and banners.
    public func adsRemoved(removeAdsID: String, at date: Date = Date()) -> Bool {
        ownedNonConsumables.contains(removeAdsID) || isSubscriber(at: date)
    }
}

public enum PurchaseOutcome: Sendable, Equatable {
    case success(productID: String)
    case pending
    case cancelled
    case failed(String)
}

/// Shown in the shop. Display strings come from the App Store (localized prices).
public struct StoreProduct: Sendable, Hashable, Identifiable {
    public var id: String
    public var displayName: String
    public var displayPrice: String
    public var kind: ProductKind
    public var hasFreeTrial: Bool
}

@MainActor
public protocol PurchaseServicing: AnyObject {
    var entitlements: Entitlements { get }
    var products: [StoreProduct] { get }
    /// Called for every verified consumable purchase so the game can grant currency exactly once.
    var onConsumable: ((ProductDefinition) -> Void)? { get set }
    var onEntitlementsChanged: ((Entitlements) -> Void)? { get set }
    func start() async
    func purchase(_ productID: String) async -> PurchaseOutcome
    func restore() async
}

/// Debug/simulator implementation with instant purchases.
@MainActor
public final class FakePurchaseService: PurchaseServicing {
    public private(set) var entitlements = Entitlements()
    public private(set) var products: [StoreProduct]
    public var onConsumable: ((ProductDefinition) -> Void)?
    public var onEntitlementsChanged: ((Entitlements) -> Void)?
    private let catalog: [ProductDefinition]

    public init(catalog: [ProductDefinition]) {
        self.catalog = catalog
        self.products = catalog.map {
            StoreProduct(id: $0.id, displayName: $0.id, displayPrice: "€0,00", kind: $0.kind,
                         hasFreeTrial: $0.kind == .subscription)
        }
    }

    public func start() async {}

    public func purchase(_ productID: String) async -> PurchaseOutcome {
        guard let definition = catalog.first(where: { $0.id == productID }) else { return .failed("unknown product") }
        switch definition.kind {
        case .consumable: onConsumable?(definition)
        case .subscription:
            entitlements.activeSubscription = productID
            entitlements.subscriptionExpires = Date().addingTimeInterval(30 * 86_400)
        case .removeAds, .nonConsumable:
            entitlements.ownedNonConsumables.insert(productID)
        }
        onEntitlementsChanged?(entitlements)
        return .success(productID: productID)
    }

    public func restore() async { onEntitlementsChanged?(entitlements) }
}

#if canImport(StoreKit)
import StoreKit

/// StoreKit 2 implementation: verified transactions only, listens for updates
/// (renewals, refunds, Ask to Buy) for the whole app lifetime.
@MainActor
public final class StoreKitPurchaseService: PurchaseServicing {
    public private(set) var entitlements = Entitlements()
    public private(set) var products: [StoreProduct] = []
    public var onConsumable: ((ProductDefinition) -> Void)?
    public var onEntitlementsChanged: ((Entitlements) -> Void)?
    private let catalog: [ProductDefinition]
    private var storeProducts: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    public init(catalog: [ProductDefinition]) {
        self.catalog = catalog
    }

    deinit { updatesTask?.cancel() }

    public func start() async {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        do {
            let loaded = try await Product.products(for: catalog.map(\.id))
            storeProducts = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            products = catalog.compactMap { definition in
                guard let product = storeProducts[definition.id] else { return nil }
                return StoreProduct(id: product.id, displayName: product.displayName,
                                    displayPrice: product.displayPrice, kind: definition.kind,
                                    hasFreeTrial: product.subscription?.introductoryOffer?.paymentMode == .freeTrial)
            }
        } catch {
            products = []
        }
        // Finish any consumables that were bought but not yet delivered.
        for await result in Transaction.unfinished { await handle(result) }
        await refreshEntitlements()
    }

    public func purchase(_ productID: String) async -> PurchaseOutcome {
        guard let product = storeProducts[productID] else { return .failed("Product not loaded") }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                return .success(productID: productID)
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("Unknown result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate == nil,
           let definition = catalog.first(where: { $0.id == transaction.productID }),
           definition.kind == .consumable {
            onConsumable?(definition)
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var next = Entitlements()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productType == .autoRenewable {
                next.activeSubscription = transaction.productID
                next.subscriptionExpires = transaction.expirationDate
            } else if transaction.productType == .nonConsumable {
                next.ownedNonConsumables.insert(transaction.productID)
            }
        }
        if next != entitlements {
            entitlements = next
            onEntitlementsChanged?(next)
        }
    }
}
#endif
