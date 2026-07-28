import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: Session
    @StateObject private var router = Router()
    @StateObject private var posCart = Cart()
    @ObservedObject private var push = PushManager.shared

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
        // The main app is designed light-only (dark mode makes some navy titles
        // blend into the background). Force light here rather than app-wide, so the
        // auth screens can still opt into `.dark` for a white status bar.
        .preferredColorScheme(.light)
        .environmentObject(router)
        .environmentObject(posCart)
        .fullScreenCover(item: $router.presented) { module in
            ModuleHost(module: module)
                .environmentObject(router)
                .environmentObject(session)
                .environmentObject(MarketStore.shared)
        }
        // Order deep link (from an order push) → full-screen order detail.
        .fullScreenCover(item: $router.orderDetail) { route in
            NavigationStack {
                OrderDetailLoader(orderId: route.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { router.orderDetail = nil }
                        }
                    }
            }
            .environmentObject(router)
            .environmentObject(session)
        }
        // FCM: ask for the permission + register the token once the signed-in UI shows,
        // then apply any route a notification tap is waiting to perform.
        .onAppear {
            PushManager.shared.requestAuthorization()
            PushManager.shared.registerCurrentToken()
            applyPendingRoute()
        }
        .onChange(of: push.pendingRoute) { _ in applyPendingRoute() }
    }

    /// Navigate where a tapped push points (parity with Android `PushManager.handleRouting`).
    private func applyPendingRoute() {
        guard let route = push.pendingRoute else { return }
        switch route {
        case .order(let id):
            if let id {
                router.presented = nil
                router.orderDetail = OrderDetailRoute(id: id)   // open the specific order
            } else {
                router.presented = nil
                router.tab = .orders
            }
        case .returns:       router.presented = .goodsReturns
        case .inventory:     router.presented = .inventory
        case .notifications: router.presented = .notifications
        }
        push.pendingRoute = nil
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
/// Marketplace uses its own header (matches Android `activity_marketplace.xml`).
struct ModuleHost: View {
    let module: Module
    @EnvironmentObject var router: Router

    private var hidesSystemNavBar: Bool { module == .marketplace }

    var body: some View {
        // Cart is fully self-contained (its own NavigationStack + a Close button
        // that dismisses the cover); present it directly. Wrapping it in ModuleHost's
        // NavigationStack swallowed that Close button, leaving no way out.
        if module == .cart {
            CartView(store: MarketStore.shared)
        } else {
            hostedModule
        }
    }

    private var hostedModule: some View {
        NavigationStack {
            Group {
                switch module {
                case .goodsReceived: GoodsReceivedView()
                case .goodsReturns:  GoodsReturnsView()
                case .inventory:     InventoryView()
                case .sales:         SalesView()
                case .invoices:      InvoicesView()
                case .finances:      FinancesView()
                case .distributors:  DistributorsView()
                case .marketplace:   MarketplaceRealView()
                case .cart:          EmptyView()   // handled directly in `body`
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
            .navigationTitle(hidesSystemNavBar ? "" : module.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(hidesSystemNavBar ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                if !hidesSystemNavBar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { router.presented = nil }
                    }
                }
            }
        }
    }
}

// MARK: - Reusable in-tab header (hamburger + title + [cart] + bell)

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    /// Opt-in cart button to the left of the bell (Dashboard only, for now) —
    /// mirrors the Android `fragment_dashboard.xml` header.
    var showsCart: Bool = false
    @EnvironmentObject var router: Router
    @ObservedObject private var badge = NotificationBadge.shared
    @ObservedObject private var market = MarketStore.shared

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
            if showsCart {
                Button { router.presented = .cart } label: {
                    Image(systemName: "cart")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(Brand.textPrimary)
                        .overlay(alignment: .topTrailing) {
                            if market.cartBadgeCount > 0 {
                                Text(market.cartBadgeCount > 99 ? "99+" : "\(market.cartBadgeCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Brand.danger)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -8)
                            }
                        }
                }
            }
            Button { router.presented = .notifications } label: {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Brand.textPrimary)
                    .overlay(alignment: .topTrailing) {
                        if badge.count > 0 {
                            Text(badge.count > 9 ? "9+" : "\(badge.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Brand.danger)
                                .clipShape(Capsule())
                                .offset(x: 8, y: -8)
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Brand.surface)
        .task {
            await badge.refresh()
            if showsCart { await market.refreshCart() }
        }
        // Coming back from a full-screen module (Cart, Marketplace, Notifications)
        // the counts have usually moved — repaint both badges on dismiss.
        .onChange(of: router.presented) { module in
            guard module == nil else { return }
            Task {
                await badge.refresh()
                if showsCart { await market.refreshCart() }
            }
        }
    }
}
