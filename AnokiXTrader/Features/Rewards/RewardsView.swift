import SwiftUI

struct RewardsView: View {
    @State private var toastMsg: String?
    private let vasCols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let vas: [(String, String)] = [
        ("Airtime", "antenna.radiowaves.left.and.right"), ("Data", "wifi"), ("Electricity", "bolt.fill"),
        ("Water", "drop.fill"), ("TV", "tv.fill"), ("More", "ellipsis")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // points hero
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Limes Points").font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                            Text("45,500").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                            Text("≈ R455 value").font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Silver").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            Image(systemName: "medal.fill").foregroundColor(.white).font(.system(size: 22))
                        }
                    }
                    ProgressView(value: 0.65).tint(.white).background(Color.white.opacity(0.25))
                    Text("2,500 points to Gold tier").font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 12) {
                    StatTile(label: "Earned This Month", value: "2,350", valueColor: Brand.success, icon: "arrow.up", iconTint: Brand.success)
                    StatTile(label: "Expiring Soon", value: "5,200", valueColor: Brand.warning, icon: "clock", iconTint: Brand.warning)
                }

                Text("Quick Redeem").font(.system(size: 17, weight: .bold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MockData.rewardVouchers) { v in
                            VStack(spacing: 8) {
                                InitialBadge(text: String(v.brand.prefix(1)), color: Color(hex: v.colorHex), size: 48)
                                Text(v.brand).font(.system(size: 12, weight: .semibold))
                                Text(v.title).font(.system(size: 10)).foregroundColor(Brand.textSecondary).multilineTextAlignment(.center)
                                Button("\(v.points) pts") { toastMsg = "Redeemed \(v.brand) voucher!" }
                                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(Brand.purple).clipShape(Capsule())
                            }
                            .frame(width: 120).padding(.vertical, 12).card(padding: 8)
                        }
                    }
                }

                Text("VAS").font(.system(size: 17, weight: .bold))
                LazyVGrid(columns: vasCols, spacing: 12) {
                    ForEach(vas, id: \.0) { v in
                        VStack(spacing: 8) {
                            Image(systemName: v.1).font(.system(size: 18)).foregroundColor(Brand.purple)
                                .frame(width: 46, height: 46).background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 13))
                            Text(v.0).font(.system(size: 11, weight: .medium))
                        }.frame(maxWidth: .infinity)
                    }
                }
                .card()

                Text("Points Activity").font(.system(size: 17, weight: .bold))
                VStack(spacing: 0) {
                    ForEach(Array(MockData.pointsActivity.enumerated()), id: \.element.id) { idx, p in
                        HStack(spacing: 12) {
                            Image(systemName: p.positive ? "plus.circle.fill" : "minus.circle.fill")
                                .foregroundColor(p.positive ? Brand.success : Brand.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.title).font(.system(size: 14, weight: .semibold))
                                Text("\(p.description) · \(p.date)").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                            }
                            Spacer()
                            Text("\(p.positive ? "+" : "−")\(p.points)")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(p.positive ? Brand.success : Brand.danger)
                        }
                        .padding(.vertical, 10)
                        if idx < MockData.pointsActivity.count - 1 { Divider() }
                    }
                }
                .card()
            }
            .padding(16)
        }
        .background(Brand.background)
        .toast($toastMsg)
    }
}
