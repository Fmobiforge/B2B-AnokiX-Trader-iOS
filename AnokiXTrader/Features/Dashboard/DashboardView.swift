import SwiftUI

/// Live trader home screen backed by `GET api/trader/dashboard`. Mirrors the trader
/// web-portal layout, stacked for mobile: today's sales + pending orders side by
/// side, then the anokiX wallet and rewards blocks, quick actions, a swipeable
/// promotions carousel, recent orders and top selling products.
@MainActor final class DashboardStore: ObservableObject {
    @Published var todaySales: TodaySalesDTO?
    @Published var wallet: DashWalletDTO?
    @Published var rewards: DashRewardsDTO?
    @Published var pendingOrders: PendingOrdersDTO?
    @Published var promotions: [PromotionDTO] = []
    @Published var recentOrders: [DashOrderDTO] = []
    @Published var topProducts: [TopProductDTO] = []
    @Published var currencySymbol = "R"
    @Published var loading = false
    @Published var loaded = false
    @Published var error: String?
    @Published var walletRefreshing = false

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getDashboard()
            let d = data.dashboard
            if let symbol = d?.meta?.currency?.symbol, !symbol.isEmpty { currencySymbol = symbol }
            todaySales = d?.today_sales
            wallet = d?.wallet
            rewards = d?.rewards
            pendingOrders = d?.pending_orders
            promotions = d?.promotions ?? []
            recentOrders = d?.recent_orders ?? []
            topProducts = d?.top_products ?? []
            loaded = true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not load your dashboard."
        }
        loading = false
    }

    /// Re-reads just the wallet block from `api/common/wallet` — the balance moves
    /// independently of the rest of the dashboard. Guards against double taps.
    func refreshWallet() async {
        guard !walletRefreshing else { return }
        walletRefreshing = true
        error = nil
        do {
            wallet = try await APIClient.shared.getWallet()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not load your wallet."
        }
        walletRefreshing = false
    }

    func money(_ value: Double?) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return currencySymbol + " " + (f.string(from: NSNumber(value: value ?? 0)) ?? "0.00")
    }
}

/// Brand colour for an order status key — parity with Android's `OrderFormat.statusColor`.
private func statusColor(_ key: String?) -> Color {
    switch key {
    case "pending":          return Color(hex: "#D97706")
    case "accepted":         return Brand.purple
    case "picking":          return Color(hex: "#2563EB")
    case "packing":          return Color(hex: "#0891B2")
    case "out_for_delivery": return Brand.warning
    case "delivered":        return Brand.success
    case "cancelled":        return Brand.danger
    default:                 return Brand.textSecondary
    }
}

struct DashboardView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: Session
    @StateObject private var store = DashboardStore()
    @State private var promoPage = 0

    private let actionCols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Welcome back", subtitle: session.storeName)
            ScrollView {
                VStack(spacing: 16) {
                    statRow
                    walletCard
                    rewardsCard
                    quickActions
                    if !store.promotions.isEmpty { promotionsCarousel }
                    recentOrders
                    topProducts
                    rewardsBanner
                }
                .padding(16)
            }
            .refreshable { await store.load() }
            .background(Brand.background)
        }
        .navigationBarHidden(true)
        .task { await store.load() }
    }

    // MARK: Row 1 — Today's Sales + Pending Orders

    private var statRow: some View {
        HStack(alignment: .top, spacing: 12) {
            todaySalesCard
            pendingOrdersCard
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var todaySalesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Today's Sales", systemImage: "chart.bar.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.topTitle)
                .labelStyle(.titleAndIcon)

            Text(store.money(store.todaySales?.amount))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Brand.textPrimary)
                .padding(.top, 6)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("\(store.todaySales?.transactions ?? 0) sales today")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            Text("\(store.todaySales?.items ?? 0) items sold")
                .font(.system(size: 11)).foregroundColor(Brand.textTertiary)

            if let delta = store.todaySales?.delta_percent {
                let up = store.todaySales?.isUp ?? true
                Label(String(format: "%.1f%%", abs(delta)),
                      systemImage: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(up ? Brand.success : Brand.danger)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(up ? Brand.successBg : Brand.dangerBg)
                    .clipShape(Capsule())
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 14)
    }

    private var pendingOrdersCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Pending Orders", systemImage: "shippingbox.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.topTitle)

            Text("\(store.pendingOrders?.count ?? 0)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Brand.textPrimary)
                .padding(.top, 6)

            Text("Total Value \(store.money(store.pendingOrders?.total_value))")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .minimumScaleFactor(0.8).lineLimit(1)

            Button("View Orders") { router.tab = .orders }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Brand.warning)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 14)
    }

    // MARK: Block 2 — anokiX wallet

    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("anokiX wallet")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.topTitle)
                    Text("Powered by IMB")
                        .font(.system(size: 10)).foregroundColor(Brand.textTertiary)
                }
                Spacer()
                if let status = store.wallet?.status, !status.isEmpty {
                    let active = store.wallet?.isActive ?? false
                    StatusBadge(text: status.capitalized,
                                fg: active ? Brand.success : Brand.warning,
                                bg: active ? Brand.successBg : Brand.warningBg)
                }
                Button {
                    Task { await store.refreshWallet() }
                } label: {
                    if store.walletRefreshing {
                        ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Brand.purple)
                            .frame(width: 20, height: 20)
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.walletRefreshing)
                .accessibilityLabel("Refresh wallet balance")
            }

            Text("Available Balance")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .padding(.top, 14)
            Text(store.money(store.wallet?.balance?.available))
                .font(.system(size: 26, weight: .bold)).foregroundColor(Brand.textPrimary)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text("Current \(store.money(store.wallet?.balance?.current)) · Pending \(store.money(store.wallet?.balance?.pending))")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .padding(.top, 3)
            if let asOf = timeOfDay(store.wallet?.balance?.as_of) {
                Text("as of \(asOf)")
                    .font(.system(size: 10)).foregroundColor(Brand.textTertiary)
                    .padding(.top, 3)
            }

            HStack(spacing: 10) {
                Button { router.tab = .wallet } label: {
                    Text("Add Money")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Brand.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Button { router.tab = .wallet } label: {
                    Text("Send Money")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Brand.purple, lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 14)

            Button("View Transactions →") { router.tab = .wallet }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.purple)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Block 3 — anokiX rewards

    private var rewardsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("anokiX rewards")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.topTitle)
            Text("Powered by Limes")
                .font(.system(size: 10)).foregroundColor(Brand.textTertiary)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rewards Points")
                        .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                    Text("\(store.rewards?.points ?? 0)")
                        .font(.system(size: 26, weight: .bold)).foregroundColor(Brand.textPrimary)
                    if let earned = store.rewards?.earned_this_month, earned > 0 {
                        Text("▲ \(earned) points this month")
                            .font(.system(size: 11)).foregroundColor(Brand.success)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Value").font(.system(size: 10)).foregroundColor(Brand.textTertiary)
                    Text(store.money(store.rewards?.value))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                }
            }
            .padding(.top, 12)

            HStack(spacing: 16) {
                Button { router.presented = .rewards } label: {
                    Label("View Rewards", systemImage: "gift.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Brand.success)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Button("View History →") { router.presented = .rewards }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Brand.success)
                Spacer()
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Actions")
            LazyVGrid(columns: actionCols, spacing: 12) {
                ForEach(MockData.quickActions, id: \.title) { qa in
                    Button { router.route(qa.route) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: qa.icon)
                                .font(.system(size: 20))
                                .foregroundColor(Brand.purple)
                                .frame(width: 48, height: 48)
                                .background(Brand.purpleLight)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(qa.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Brand.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    // MARK: Promotions carousel

    private var promotionsCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Promotions", actionTitle: "View All") {
                router.presented = .marketplace
            }
            TabView(selection: $promoPage) {
                ForEach(Array(store.promotions.enumerated()), id: \.element.id) { idx, promo in
                    promoSlide(promo).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 260)

            if store.promotions.count > 1 {
                HStack(spacing: 8) {
                    Spacer()
                    ForEach(Array(store.promotions.indices), id: \.self) { i in
                        Capsule()
                            .fill(i == promoPage ? Brand.purple : Brand.border)
                            .frame(width: i == promoPage ? 18 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: promoPage)
                    }
                    Spacer()
                }
            }
        }
    }

    private func promoSlide(_ promo: PromotionDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = MediaUrls.resolve(promo.banner_file?.file_url) {
                RemoteImage(url: url)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Text(promo.name ?? "")
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                .lineLimit(1)
                .padding(.top, 12)
            if let description = promo.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#C7D2FE"))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            if let until = shortDate(promo.end_date) {
                Text("Valid until \(until)")
                    .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                    .padding(.top, 6)
            }
            Button("Shop Now") { router.presented = .marketplace }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: [Color(hex: "#0F172A"), Color(hex: "#1E1B4B")],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Recent orders

    private var recentOrders: some View {
        ListCard(title: "Recent Orders", actionTitle: "View All", action: { router.tab = .orders }) {
            if store.recentOrders.isEmpty {
                emptyState(store.loaded ? "No orders yet." : "Loading…")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.recentOrders.enumerated()), id: \.element.id) { idx, o in
                        Button { router.tab = .orders } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(o.order_number ?? "")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Brand.textPrimary)
                                    if let name = o.distributor?.display_name, !name.isEmpty {
                                        Text(name)
                                            .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                    }
                                    Text(createdAt(o.created_at))
                                        .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(store.money(o.total_amount))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Brand.textPrimary)
                                    let color = statusColor(o.status_key)
                                    StatusBadge(text: o.status ?? "",
                                                fg: color, bg: color.opacity(0.14))
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if idx < store.recentOrders.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    // MARK: Top selling products

    private var topProducts: some View {
        ListCard(title: "Top Selling Products") {
            if store.topProducts.isEmpty {
                emptyState(store.loaded ? "No sales yet this week" : "Loading…")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.topProducts.enumerated()), id: \.element.id) { idx, p in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Brand.purple)
                                .frame(width: 28, height: 28)
                                .background(Brand.purpleLight).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name ?? "")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Brand.textPrimary)
                                Text("\(Int(p.quantity ?? 0)) sold")
                                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                            }
                            Spacer()
                            Text(store.money(p.revenue))
                                .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.success)
                        }
                        .padding(.vertical, 9)
                        if idx < store.topProducts.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    // MARK: Static rewards banner

    private var rewardsBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "gift.fill").font(.system(size: 22)).foregroundColor(.white)
                .frame(width: 48, height: 48).background(Color.white.opacity(0.2)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text("Unlock bigger rewards!")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text("You're 2 orders away from higher rewards.")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                ProgressView(value: 0.8).tint(.white).background(Color.white.opacity(0.25))
            }
            Spacer()
        }
        .padding(16)
        .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark],
                                   startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { router.presented = .rewards }
    }

    // MARK: Helpers

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12)).foregroundColor(Brand.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }

    /// "2026-07-20T02:58:47+00:00" → local "04:58".
    private func timeOfDay(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: iso) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "HH:mm"
        return out.string(from: date)
    }

    /// "2026-12-30" → "30 Dec 2026".
    private func shortDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.dateFormat = "dd MMM yyyy"
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: date)
    }

    /// "15/07/2026 13:58:04" → "15 Jul 2026, 13:58".
    private func createdAt(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.dateFormat = "dd/MM/yyyy HH:mm:ss"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.dateFormat = "dd MMM yyyy, HH:mm"
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: date)
    }
}
