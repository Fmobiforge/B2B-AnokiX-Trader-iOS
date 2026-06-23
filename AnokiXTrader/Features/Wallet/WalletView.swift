import SwiftUI

struct WalletView: View {
    @State private var toastMsg: String?
    private let actions: [(String, String)] = [
        ("Send", "arrow.up.right"), ("Add Money", "plus"), ("Pay Bills", "doc.text"),
        ("Buy Airtime", "antenna.radiowaves.left.and.right"), ("Statement", "list.bullet.rectangle"), ("Settle", "building.columns")
    ]
    private let actionCols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "anokiX wallet", subtitle: "Powered by IMB")
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    actionGrid
                    transactions
                }
                .padding(16)
            }
            .background(Brand.background)
        }
        .navigationBarHidden(true)
        .toast($toastMsg)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Total Wallet Balance").font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("Powered by IMB")
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.18)).clipShape(Capsule())
            }
            Text("R 15,450.00").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available").font(.system(size: 11)).foregroundColor(.white.opacity(0.75))
                    Text("R 12,950.00").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pending").font(.system(size: 11)).foregroundColor(.white.opacity(0.75))
                    Text("R 2,500.00").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }
            }
            Text("IMB Business Account ···3345 · Next settlement 15 May")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionGrid: some View {
        LazyVGrid(columns: actionCols, spacing: 12) {
            ForEach(actions, id: \.0) { a in
                Button { toastMsg = "\(a.0) — coming soon." } label: {
                    VStack(spacing: 8) {
                        Image(systemName: a.1).font(.system(size: 18)).foregroundColor(Brand.purple)
                            .frame(width: 46, height: 46).background(Brand.purpleLight)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        Text(a.0).font(.system(size: 11, weight: .medium)).foregroundColor(Brand.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private var transactions: some View {
        ListCard(title: "Recent Transactions", actionTitle: "See All", action: {}) {
            VStack(spacing: 0) {
                ForEach(Array(MockData.walletTransactions.enumerated()), id: \.element.id) { idx, t in
                    HStack(spacing: 12) {
                        Image(systemName: icon(t.type))
                            .font(.system(size: 15))
                            .foregroundColor(t.positive ? Brand.success : Brand.danger)
                            .frame(width: 40, height: 40)
                            .background((t.positive ? Brand.success : Brand.danger).opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                            Text("\(t.subtitle) · \(t.date)").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(t.positive ? "+" : "−")\(Money.rand(t.amount))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(t.positive ? Brand.success : Brand.danger)
                            Text(t.status).font(.system(size: 11)).foregroundColor(Brand.success)
                        }
                    }
                    .padding(.vertical, 10)
                    if idx < MockData.walletTransactions.count - 1 { Divider() }
                }
            }
        }
    }

    private func icon(_ type: String) -> String {
        switch type {
        case "received": return "arrow.down.left"
        case "sent": return "arrow.up.right"
        case "settlement": return "building.columns"
        case "airtime": return "antenna.radiowaves.left.and.right"
        default: return "creditcard"
        }
    }
}
