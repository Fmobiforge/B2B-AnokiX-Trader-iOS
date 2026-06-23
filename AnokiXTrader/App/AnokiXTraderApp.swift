import SwiftUI
import UIKit

@main
struct AnokiXTraderApp: App {
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
