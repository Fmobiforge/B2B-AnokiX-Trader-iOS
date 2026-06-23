import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: Session
    @StateObject private var router = Router()
    @StateObject private var posCart = Cart()

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomTabBar(selection: $router.tab)
            }

            if router.drawerOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { router.drawerOpen = false } }
                DrawerView()
                    .frame(width: 300)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeOut(duration: 0.22), value: router.drawerOpen)
        .environmentObject(router)
        .environmentObject(posCart)
        .fullScreenCover(item: $router.presented) { module in
            ModuleHost(module: module)
                .environmentObject(router)
                .environmentObject(session)
                .environmentObject(MarketStore.shared)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch router.tab {
        case .home:
            NavigationStack { DashboardView() }
        case .sell:
            NavigationStack { SellView() }
        case .orders:
            NavigationStack { OrdersView() }
        case .wallet:
            NavigationStack { WalletView() }
        case .more:
            NavigationStack { MoreView() }
        }
    }
}

/// Hosts a secondary module full-screen with a navigation bar + Close button.
struct ModuleHost: View {
    let module: Module
    @EnvironmentObject var router: Router

    var body: some View {
        NavigationStack {
            Group {
                switch module {
                case .inventory:     InventoryView()
                case .marketplace:   MarketplaceRealView()
                case .payments:      PaymentsView()
                case .airtime:       AirtimeView()
                case .rewards:       RewardsView()
                case .promotions:    OffersView()
                case .customers:     CustomersView()
                case .analytics:     AnalyticsView()
                case .reports:       ReportsView()
                case .notifications: NotificationsView()
                case .settings:      SettingsView()
                case .support:       SupportView()
                }
            }
            .navigationTitle(module.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { router.presented = nil }
                }
            }
        }
    }
}

// MARK: - Reusable in-tab header (hamburger + title + bell)

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    @EnvironmentObject var router: Router

    var body: some View {
        HStack(spacing: 12) {
            Button { withAnimation { router.drawerOpen = true } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
            }
            Spacer()
            Button { router.presented = .notifications } label: {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Brand.textPrimary)
                    .overlay(Circle().fill(Brand.danger).frame(width: 7, height: 7).offset(x: 7, y: -7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Brand.surface)
    }
}
