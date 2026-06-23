import SwiftUI

struct AnalyticsView: View {
    private let kpiCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let kpis: [(String, String, String, Color)] = [
        ("Sales", "R18,450", "cart.fill", Brand.purple),
        ("Revenue", "R456,200", "banknote.fill", Brand.success),
        ("Wallet", "R8,750", "wallet.pass.fill", Brand.info),
        ("Rewards", "R1,250", "gift.fill", Brand.warning),
    ]
    private let topSellers: [(String, String)] = [
        ("Fresh Milk 2L", "R 2,880"), ("Brown Bread", "R 1,440"), ("Eggs (30 pack)", "R 2,240"),
        ("Cooking Oil 2L", "R 3,300"), ("Soft Drink 2L", "R 1,140"),
    ]
    private let insights: [(String, String, Color)] = [
        ("Fast Moving", "24", Brand.success), ("Slow Moving", "6", Brand.warning),
        ("Low Stock", "8", Brand.warning), ("Out of Stock", "3", Brand.danger),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: kpiCols, spacing: 12) {
                    ForEach(kpis, id: \.0) { k in
                        StatTile(label: k.0, value: k.1, valueColor: k.3, icon: k.2, iconTint: k.3)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Revenue Overview")
                    LineChartView(values: MockData.salesOverview, color: Brand.purple)
                }.card()

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Sales by Category")
                    HStack(spacing: 16) {
                        DonutChartView(slices: MockData.topCategories, size: 130)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(MockData.topCategories) { c in
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: c.colorHex)).frame(width: 10, height: 10)
                                    Text(c.name).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                                    Spacer()
                                    Text("\(Int(c.percentage))%").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textSecondary)
                                }
                            }
                        }
                    }
                }.card()

                // Business health
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Business Health Score")
                    HStack {
                        Text("92").font(.system(size: 40, weight: .bold)).foregroundColor(Brand.success)
                        Text("/ 100").font(.system(size: 16)).foregroundColor(Brand.textSecondary)
                        Spacer()
                        StatusBadge(text: "Excellent", fg: Brand.success, bg: Brand.successBg)
                    }
                    ProgressView(value: 0.92).tint(Brand.success)
                }.card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Top Selling Products")
                    ForEach(Array(topSellers.enumerated()), id: \.offset) { idx, s in
                        HStack {
                            Text("\(idx+1)").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.purple)
                                .frame(width: 26, height: 26).background(Brand.purpleLight).clipShape(Circle())
                            Text(s.0).font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text(s.1).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.success)
                        }.padding(.vertical, 7)
                        if idx < topSellers.count - 1 { Divider() }
                    }
                }.card()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Inventory Insights")
                    LazyVGrid(columns: kpiCols, spacing: 12) {
                        ForEach(insights, id: \.0) { i in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(i.1).font(.system(size: 22, weight: .bold)).foregroundColor(i.2)
                                Text(i.0).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(i.2.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }.card()

                // Smart insights
                VStack(alignment: .leading, spacing: 8) {
                    Label("Smart Insights", systemImage: "sparkles").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text("Beverages sales are up 18% this week. Consider restocking Coca-Cola 2L and Fresh Milk before the weekend peak.")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.9))
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(16)
        }
        .background(Brand.background)
    }
}
