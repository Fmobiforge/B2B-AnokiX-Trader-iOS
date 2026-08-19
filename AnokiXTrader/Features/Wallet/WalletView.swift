import SwiftUI
import UIKit

/// The anokiX wallet (powered by IMB): live balance, the recent movements on it, and the
/// two things a trader can actually do with it from a phone — put money in with a card
/// (PayCloud top-up) and stand a debit order against it.
///
/// The web portal's Send Money / Pay Bills / Move to Bank / QR tiles are not here. There
/// is no API behind any of them for a trader, and a wallet screen that offers to move a
/// shopkeeper's money and then cannot is worse than one that does not offer.
struct WalletView: View {
    @EnvironmentObject var router: Router
    @StateObject private var store = WalletStore()

    @State private var showTopUp = false
    @State private var showDebitOrder = false
    @State private var toastMsg: String?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "anokiX wallet", subtitle: "Manage your money — Powered by IMB")
            ScrollView {
                // Stacked in the portal's reading order (wallet01.png): balance, then
                // the settlement account, then the actions grid, then the two lists.
                VStack(spacing: 16) {
                    balanceCard
                    accountCard
                    actionGrid
                    transactionsCard
                    debitOrdersCard
                }
                .padding(16)
            }
            .background(Brand.background)
            .refreshable { await store.load() }
        }
        .navigationBarHidden(true)
        .toast($toastMsg)
        .task { if store.wallet == nil { await store.load() } }
        .sheet(isPresented: $showTopUp) {
            TopUpSheet {
                // Money has actually landed, so read the balance again to prove it.
                Task { await store.loadWallet(refresh: true) }
            }
        }
        .sheet(isPresented: $showDebitOrder) {
            DebitOrderSheet(accountNumber: store.accountNumber,
                            limits: store.debit?.bounds ?? DebitLimitsDTO()) { message in
                toastMsg = message ?? "Debit order authorised"
                Task { await store.loadDebitOrders() }
            }
        }
        .onChange(of: store.error) { message in
            if let message { toastMsg = message; store.error = nil }
        }
    }

    // MARK: - Balance card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Total Wallet Balance")
                    .font(.system(size: 13)).foregroundColor(Color(hex: "#E9DDFF"))
                Spacer()
                // A nil icon turns the button into a spinner — it stands in for the
                // first load as well as a manual refresh, so the card is never silently
                // showing placeholder zeroes.
                glassButton(store.busy ? nil : "arrow.clockwise",
                            label: "Refresh wallet balance") {
                    Task { await store.refreshBalance() }
                }
                .disabled(store.busy)
                glassButton(store.balancesHidden ? "eye.slash" : "eye",
                            label: store.balancesHidden ? "Show balance" : "Hide balance") {
                    store.balancesHidden.toggle()
                }
            }

            Text(store.cardMoney(store.balance?.current))
                .font(.system(size: 30, weight: .bold)).foregroundColor(.white)

            HStack(spacing: 20) {
                figure("Available Balance", store.cardMoney(store.balance?.available))
                figure("Pending", store.cardMoney(store.balance?.pending))
            }

            if let asOf = store.asOfLabel {
                Text(asOf).font(.system(size: 11)).foregroundColor(Color(hex: "#C9B6FF"))
            }

            // Top-ups need a live wallet to land in, so the button goes away and says why.
            if store.isActive {
                Button {
                    showTopUp = true
                } label: {
                    Label("Top Up Wallet", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Brand.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if store.wallet != nil {
                Text(inactiveNotice)
                    .font(.system(size: 12)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Divider().background(Color.white.opacity(0.25))

            HStack {
                Text("anokiX wallet · Powered by IMB")
                    .font(.system(size: 10)).foregroundColor(Color(hex: "#D6C4FF"))
                Spacer()
                if !store.statusLabel.isEmpty {
                    Text(store.statusLabel)
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: "#8B5CF6"), Color(hex: "#6D28D9")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var inactiveNotice: String {
        let reason = store.wallet?.last_error ?? ""
        return reason.isEmpty ? "Your wallet is not set up yet." : reason
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundColor(Color(hex: "#D6C4FF"))
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A translucent icon button on the purple card. A nil icon shows a spinner instead.
    private func glassButton(_ icon: String?, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Quick actions

    /// The tiles sit inside one card, as on the portal, rather than being four cards.
    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            HStack(spacing: 4) {
                action("Add Money", "plus", Brand.success, Brand.successBg) { openTopUp() }
                action("Debit Order", "calendar", Brand.info, Brand.infoBg) { openDebitOrder() }
                action("Buy Airtime", "antenna.radiowaves.left.and.right",
                       Brand.warning, Brand.warningBg) { router.presented = .airtime }
                // "Statement" is the wallet ledger, which is exactly what Finances shows.
                action("Statement", "doc.text", Brand.purple, Brand.purpleLight) {
                    router.presented = .finances
                }
            }
        }
        .card()
    }

    /// Pale tile, saturated glyph — the tile colour must stay far lighter than the icon
    /// colour or the icon disappears into its own background.
    private func action(_ title: String, _ icon: String, _ tint: Color, _ tile: Color,
                        _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(tint)
                    .frame(width: 46, height: 46)
                    .background(tile)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// Top-ups need a live wallet to land in.
    private func openTopUp() {
        guard store.isActive else {
            toastMsg = "Your wallet is not active yet, so this cannot be used."
            return
        }
        showTopUp = true
    }

    private func openDebitOrder() {
        guard store.debitAvailable else {
            toastMsg = "Debit orders are not available on this account yet."
            return
        }
        showDebitOrder = true
    }

    // MARK: - IMB account

    private var accountCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 16))
                .foregroundColor(Brand.purple)
                .frame(width: 40, height: 40)
                .background(Brand.purpleLight)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("IMB Business Account")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                Text(store.accountNumber ?? "—")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            if let number = store.accountNumber {
                Button {
                    UIPasteboard.general.string = number
                    toastMsg = "Account number copied"
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15))
                        .foregroundColor(Brand.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy account number")
            }
        }
        .card(padding: 14)
    }

    // MARK: - Recent transactions

    private var transactionsCard: some View {
        ListCard(title: "Recent Transactions", actionTitle: "View all",
                 action: { router.presented = .finances }) {
            if store.transactions.isEmpty {
                emptyLine("No transactions yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.transactions.enumerated()), id: \.offset) { idx, t in
                        transactionRow(t)
                        if idx < store.transactions.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func transactionRow(_ t: DashWalletTxnDTO) -> some View {
        // The API sends no description, only a signed amount — so the sign is the only
        // thing that says which way the money went.
        let value = Double(t.amount ?? "0") ?? 0
        let incoming = value >= 0
        let tone = incoming ? Brand.success : Brand.danger
        return HStack(spacing: 12) {
            Image(systemName: incoming ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tone)
                .frame(width: 38, height: 38)
                .background(tone.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(incoming ? "Money in" : "Money out")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                Text(WalletFmt.dateTime(t.date))
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(incoming ? "+" : "−")R\(WalletFmt.decimal(abs(value)))")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(tone)
                if t.pending == true {
                    StatusBadge(text: "Pending", fg: Brand.warning, bg: Brand.warningBg)
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Debit orders

    private var debitOrdersCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Debit Orders")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                if store.debitAvailable {
                    Button { showDebitOrder = true } label: {
                        Label("New", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Brand.purple)
                    }
                    .buttonStyle(.plain)
                }
            }

            // available=false means the IMB payment rail is not configured for this
            // merchant, so say that plainly instead of offering a form that can only fail.
            Text(store.debitAvailable
                 ? "Standing instructions for IMB to draw money into this wallet."
                 : "Debit orders are not available on this account yet.")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.debitOrders.isEmpty {
                emptyLine("No debit orders yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.debitOrders.enumerated()), id: \.element.id) { idx, r in
                        debitRow(r)
                        if idx < store.debitOrders.count - 1 { Divider() }
                    }
                }
            }
        }
        .card()
    }

    private func debitRow(_ r: DebitRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Brand.purple)
                    .frame(width: 38, height: 38)
                    .background(Brand.purpleLight)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.reference?.isEmpty == false ? r.reference! : "—")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    Text(r.scheduleLabel)
                        .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(r.money)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                    StatusBadge(text: r.statusLabel, fg: r.statusTone.fg, bg: r.statusTone.bg)
                }
            }
            // A failed instruction is only useful if it says why IMB refused it.
            if r.isFailed, let reason = r.last_error, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 11)).foregroundColor(Brand.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Brand.dangerBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.leading, 50)
            }
        }
        .padding(.vertical, 10)
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }
}
