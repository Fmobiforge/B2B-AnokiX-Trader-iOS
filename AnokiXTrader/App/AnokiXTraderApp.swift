import SwiftUI
import UIKit

@main
struct AnokiXTraderApp: App {
    @StateObject private var session = Session()

    init() {
        TabBarStyle.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Brand.purple)
        }
    }
}

/// Explicit UITabBar styling so icons and labels stay visible on every device/simulator.
private enum TabBarStyle {
    private static let purple = UIColor(red: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1)
    private static let secondary = UIColor(red: 100 / 255, green: 116 / 255, blue: 139 / 255, alpha: 1)
    private static let border = UIColor(red: 226 / 255, green: 232 / 255, blue: 240 / 255, alpha: 1)

    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = border

        let normalTitle: [NSAttributedString.Key: Any] = [
            .foregroundColor: secondary,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]
        let selectedTitle: [NSAttributedString.Key: Any] = [
            .foregroundColor: purple,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        ]

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            layout.normal.iconColor = secondary
            layout.normal.titleTextAttributes = normalTitle
            layout.selected.iconColor = purple
            layout.selected.titleTextAttributes = selectedTitle
        }

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = purple
        tabBar.unselectedItemTintColor = secondary
        tabBar.barTintColor = .white
        tabBar.isTranslucent = false
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
