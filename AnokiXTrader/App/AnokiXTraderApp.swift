import SwiftUI
import UIKit

@main
struct AnokiXTraderApp: App {
    @StateObject private var session = Session()

    init() {
        // Tab bar / nav bar chrome to match the light portal theme.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
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
