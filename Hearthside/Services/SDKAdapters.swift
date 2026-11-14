import Foundation
import SwiftUI
import GameServices

// Adapters for third-party SDKs. They live in the app target (not in the GameServices
// package) because the SDKs are linked by the app via SPM. Each block compiles only
// when its SDK is present, so the app still builds before the SDKs are added.
// Written against Google Mobile Ads SDK 12, UMP 3 and Firebase 11.

#if canImport(GoogleMobileAds) && canImport(UIKit)
@preconcurrency import GoogleMobileAds
import UIKit

/// Google Mobile Ads (SDK 12+) adapter.
@MainActor
public final class GoogleAdNetwork: NSObject, AdNetwork, FullScreenContentDelegate {
    private let units: AdUnitIDs
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var dismissContinuation: CheckedContinuation<Void, Never>?
    private var earnedReward = false
    public var onRevenue: ((AdRevenue) -> Void)?

    public init(units: AdUnitIDs) {
        self.units = units
    }

    public func start() async {
        _ = await MobileAds.shared.start()
    }

    public func preload(_ format: GameServices.AdFormat) async {
        switch format {
        case .interstitial where interstitial == nil:
            interstitial = try? await InterstitialAd.load(with: units.interstitial, request: Request())
            interstitial?.fullScreenContentDelegate = self
            attachRevenue(interstitial, format: .interstitial)
        case .rewarded where rewarded == nil:
            rewarded = try? await RewardedAd.load(with: units.rewarded, request: Request())
            rewarded?.fullScreenContentDelegate = self
            attachRevenue(rewarded, format: .rewarded)
        default:
            break
        }
    }

    private func attachRevenue(_ ad: AnyObject?, format: GameServices.AdFormat) {
        let handler: (AdValue) -> Void = { [weak self] value in
            guard let network = self else { return }
            let micros = value.value.multiplying(byPowerOf10: 6).int64Value
            let currency = value.currencyCode
            Task { @MainActor in
                network.onRevenue?(AdRevenue(format: format, valueMicros: micros,
                                             currency: currency, placement: format.rawValue))
            }
        }
        (ad as? InterstitialAd)?.paidEventHandler = handler
        (ad as? RewardedAd)?.paidEventHandler = handler
    }

    public func isReady(_ format: GameServices.AdFormat) -> Bool {
        switch format {
        case .interstitial: return interstitial != nil
        case .rewarded: return rewarded != nil
        case .banner: return true
        }
    }

    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
    }

    public func showInterstitial(placement: String) async -> Bool {
        guard let ad = interstitial, let root = rootViewController else { return false }
        interstitial = nil
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            ad.present(from: root)
        }
        return true
    }

    public func showRewarded(placement: String) async -> Bool {
        guard let ad = rewarded, let root = rootViewController else { return false }
        rewarded = nil
        earnedReward = false
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            ad.present(from: root) { MainActor.assumeIsolated { self.earnedReward = true } }
        }
        return earnedReward
    }

    public nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.dismissContinuation?.resume()
            self.dismissContinuation = nil
        }
    }

    public nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        adDidDismissFullScreenContent(ad)
    }
}
#endif

#if canImport(FirebaseRemoteConfig)
@preconcurrency import FirebaseRemoteConfig

/// Firebase-backed source. Call `fetchAndActivate()` at launch; values apply from then on.
public final class FirebaseConfigSource: ConfigValueSource, @unchecked Sendable {
    private let remoteConfig = RemoteConfig.remoteConfig()

    public init(minimumFetchInterval: TimeInterval = 3_600) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        remoteConfig.configSettings = settings
    }

    public func fetchAndActivate() async {
        _ = try? await remoteConfig.fetchAndActivate()
    }

    public func value(for name: String) -> String? {
        let value = remoteConfig.configValue(forKey: name)
        return value.source == .static ? nil : value.stringValue
    }
}
#endif

#if canImport(FirebaseAnalytics)
@preconcurrency import FirebaseAnalytics

public struct FirebaseAnalyticsSink: AnalyticsSink {
    public init() {}
    public func log(_ event: String, _ parameters: [String: String]) {
        Analytics.logEvent(event, parameters: parameters.isEmpty ? nil : parameters)
    }
    public func setUserProperty(_ value: String?, for name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
#endif

#if canImport(UserMessagingPlatform) && canImport(UIKit)
@preconcurrency import UserMessagingPlatform
import UIKit
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Google UMP (v3) + Apple ATT.
@MainActor
public final class UMPConsentService: ConsentServicing {
    public private(set) var state = ConsentState()
    private let debugGeography: Bool

    public init(debugGeographyEEA: Bool = false) {
        self.debugGeography = debugGeographyEEA
    }

    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
    }

    public func gatherConsent() async -> ConsentState {
        let parameters = RequestParameters()
        if debugGeography {
            let debug = DebugSettings()
            debug.geography = .EEA
            parameters.debugSettings = debug
        }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if let root = rootViewController {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Fall through: canRequestAds reflects the last known consent.
        }
        #if canImport(AppTrackingTransparency)
        let status = await ATTrackingManager.requestTrackingAuthorization()
        state.trackingAuthorized = status == .authorized
        #endif
        state.canRequestAds = ConsentInformation.shared.canRequestAds
        state.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        return state
    }

    public func presentPrivacyOptions() async {
        guard let root = rootViewController else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
        state.canRequestAds = ConsentInformation.shared.canRequestAds
    }
}
#endif

// MARK: - Banner (village and menus only, never on the table)

#if canImport(GoogleMobileAds) && canImport(UIKit)
struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let width = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }.first ?? 375
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdUnits.current.banner
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
#else
/// Placeholder while the Google Mobile Ads SDK is not linked.
struct BannerAdView: View {
    var body: some View { Color.clear.frame(height: 0) }
}
#endif
