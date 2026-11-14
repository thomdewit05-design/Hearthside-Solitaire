import SwiftUI
import HearthsideCore
#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
        return true
    }
}

@main
struct HearthsideApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .task { await app.start() }
                .preferredColorScheme(.dark)
                .tint(.hearthRed)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .table: TableView()
                    case .village: VillageView()
                    case .house(let id): HouseDetailView(houseID: id)
                    case .daily: DailyChallengeView()
                    case .stats: StatsView()
                    case .shop: ShopView()
                    case .settings: SettingsView()
                    #if DEBUG
                    case .debug: DebugMenuView()
                    #endif
                    }
                }
        }
        .sheet(item: $app.pendingOffer) { offer in
            OfferSheet(offer: offer).presentationDetents([.medium])
        }
    }
}
