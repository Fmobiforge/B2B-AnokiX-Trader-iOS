import SwiftUI
import UIKit
import GoogleMaps

/// Registers the Google Maps SDK key at launch (parity with the Distributor app's
/// `AppDelegate`, which the SwiftUI lifecycle reaches via `UIApplicationDelegateAdaptor`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        GMSServices.provideAPIKey(GoogleMapsConfig.apiKey)
        return true
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
