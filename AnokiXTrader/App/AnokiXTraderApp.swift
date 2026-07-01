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
        return true
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
        case .main:     MainTabView()
        }
    }
}
