import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: Session

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let actionCols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Welcome back", subtitle: session.storeName)
            ScrollView {
                VStack(spacing: 16) {
                    kpiGrid
                    quickActions
                    salesOverview
                    recentOrders
                    rewardsBanner
                    topProducts
                    lowStock
                    promoBanner
                }
                .padding(16)
            }
            .background(Brand.background)
        }
        .navigationBarHidden(true)
    }

    // 4 KPI cards
    private var kpiGrid: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(MockData.kpis) { kpi in
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: kpi.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: kpi.tintHex))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: kpi.tintHex).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(kpi.value).font(.system(size: 20, weight: .bold)).foregroundColor(Color(hex: kpi.tintHex))
                    Text(kpi.title).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
            }
        }
    }

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

    private var salesOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sales Overview").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Text("R28,640").font(.system(size: 22, weight: .bold)).foregroundColor(Brand.textPrimary)
                }
                Spacer()
                Label("12.4%", systemImage: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Brand.success)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Brand.successBg).clipShape(Capsule())
            }
            LineChartView(values: MockData.salesOverview)
            HStack {
                ForEach(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"], id: \.self) { d in
                    Text(d).font(.system(size: 10)).foregroundColor(Brand.textTertiary).frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }

    private var recentOrders: some View {
        ListCard(title: "Recent Orders", actionTitle: "View All", action: { router.tab = .orders }) {
            VStack(spacing: 0) {
                ForEach(Array(MockData.recentOrders.enumerated()), id: \.element.id) { idx, o in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(o.orderId).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                            Text(o.date).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(o.amount).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                            StatusBadge(text: o.statusLabel, fg: Color(hex: o.statusColor), bg: Color(hex: o.statusColor).opacity(0.14))
                        }
                    }
                    .padding(.vertical, 10)
                    if idx < MockData.recentOrders.count - 1 { Divider() }
                }
            }
        }
    }

    private var rewardsBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "gift.fill").font(.system(size: 22)).foregroundColor(.white)
                .frame(width: 48, height: 48).background(Color.white.opacity(0.2)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text("Unlock bigger rewards!").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text("8 of 10 orders to your next reward").font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                ProgressView(value: 0.8).tint(.white).background(Color.white.opacity(0.25))
            }
            Spacer()
        }
        .padding(16)
        .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var topProducts: some View {
        ListCard(title: "Top Selling Products") {
            VStack(spacing: 0) {
                ForEach(Array(MockData.topProducts.enumerated()), id: \.element.id) { idx, p in
                    HStack(spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(Brand.purple)
                            .frame(width: 28, height: 28).background(Brand.purpleLight).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                            Text(p.subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        Text(p.badge).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.success)
                    }
                    .padding(.vertical, 9)
                    if idx < MockData.topProducts.count - 1 { Divider() }
                }
            }
        }
    }

    private var lowStock: some View {
        ListCard(title: "Low Stock Alerts", actionTitle: "View", action: { router.presented = .inventory }) {
            VStack(spacing: 0) {
                ForEach(Array(MockData.lowStockAlerts.enumerated()), id: \.element.id) { idx, a in
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Brand.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                            Text(a.subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        Text(a.badge).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.danger)
                    }
                    .padding(.vertical, 9)
                    if idx < MockData.lowStockAlerts.count - 1 { Divider() }
                }
            }
        }
    }

    private var promoBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stock Up & Save").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                Text("Exclusive marketplace deals this week").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            Button("Shop") { router.presented = .marketplace }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                .background(Brand.warning).clipShape(Capsule())
        }
        .card()
    }
}
