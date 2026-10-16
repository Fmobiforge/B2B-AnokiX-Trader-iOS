import SwiftUI
import UIKit
import GoogleMaps
import FirebaseMessaging

/// Registers the Google Maps SDK key and boots Firebase Cloud Messaging at launch
/// (parity with the Distributor app's `AppDelegate`, reached via `UIApplicationDelegateAdaptor`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        GMSServices.provideAPIKey(GoogleMapsConfig.apiKey)
        PushManager.shared.configure()   // FirebaseApp.configure() + messaging/notification delegates
        Self.applyPortalNavigationBar()
        return true
    }

    /// Trader Portal page header: white bar, #DCE1E8 hairline, navy (#1A237E) Inter title.
    /// Covers every system navigation bar (module hosts, sheets, pushed detail screens).
    private static func applyPortalNavigationBar() {
        let navy = UIColor(red: 26 / 255, green: 35 / 255, blue: 126 / 255, alpha: 1)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor(red: 220 / 255, green: 225 / 255, blue: 232 / 255, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: navy,
                                          .font: AppFont.uiFont(17, .semibold)]
        appearance.largeTitleTextAttributes = [.foregroundColor: navy,
                                               .font: AppFont.uiFont(30, .bold)]
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.compactAppearance = appearance
        bar.scrollEdgeAppearance = appearance
    }

    /// Forward the APNs device token to FCM so it can mint the registration token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // APNs registration failed (e.g. Simulator / no push entitlement) — pushes are
        // simply unavailable; the rest of the app keeps working.
    }
}

@main
struct AnokiXTraderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(MarketStore.shared)
                .tint(Brand.purple)
                // Default for any Text / TextField without its own font: Inter, body size.
                .font(.app(17))
                .onOpenURL { url in
                    // anokix://topup-return — PayCloud is finished with the wallet
                    // top-up checkout page. It carries no result we would trust: the
                    // wallet is credited by PayCloud's signed webhook, verified
                    // server-side, so all this does is close the browser and let the
                    // Top Up sheet ask the server where the order actually got to.
                    if url.scheme?.lowercased() == "anokix", url.host == "topup-return" {
                        NotificationCenter.default.post(name: .topupReturned, object: nil)
                    }
                }
        }
    }
}

/// Switches between the auth flow and the main app based on the session stage.
struct RootView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        switch session.stage {
        case .splash:   SplashView()
        case .welcome:  WelcomeView()
        case .login:    LoginView()
        case .register: RegisterView()
        case .pendingApproval: PendingApprovalView()
        case .main:     MainTabView()
        }
    }
}
