import SwiftUI
import UIKit

/// The anokiX wallet (powered by IMB): live balance, the recent movements on it, and the
/// two things a trader can actually do with it from a phone — put money in with a card
/// (PayCloud top-up) and stand a debit order against it.
///
/// Presented as a module of its own (`Module.wallet`) rather than a tab, so Close returns
/// the trader to whatever they were doing — the counterpart of Android `WalletActivity`.
/// `ModuleHost` supplies the navigation bar and the Close button.
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
        ScrollView {
            // Stacked in the portal's reading order (wallet01.png): balance, then
            // the settlement account, then the actions grid, then the two lists.
            VStack(spacing: 16) {
                // The strapline reads as a line of page copy rather than nav-bar chrome,
                // so it gets the full width instead of ellipsising next to the title.
                // Same placement as RewardsView.
                Text("Manage your money — Powered by IMB")
                    .font(.app(12)).foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.app(13)).foregroundColor(Color(hex: "#E9DDFF"))
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
                .font(.app(30, .bold)).foregroundColor(.white)

            HStack(spacing: 20) {
                figure("Available Balance", store.cardMoney(store.balance?.available))
                figure("Pending", store.cardMoney(store.balance?.pending))
            }

            if let asOf = store.asOfLabel {
                Text(asOf).font(.app(11)).foregroundColor(Color(hex: "#C9B6FF"))
            }

            // Top-ups need a live wallet to land in, so the button goes away and says why.
            if store.isActive {
                Button {
                    showTopUp = true
                } label: {
                    Label("Top Up Wallet", systemImage: "plus")
                        .font(.app(15, .semibold))
                        .foregroundColor(Brand.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if store.wallet != nil {
                Text(inactiveNotice)
                    .font(.app(12)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Divider().background(Color.white.opacity(0.25))

            HStack {
                Text("anokiX wallet · Powered by IMB")
                    .font(.app(10)).foregroundColor(Color(hex: "#D6C4FF"))
                Spacer()
                if !store.statusLabel.isEmpty {
                    Text(store.statusLabel)
                        .font(.app(10, .semibold)).foregroundColor(.white)
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
            Text(label).font(.app(11)).foregroundColor(Color(hex: "#D6C4FF"))
            Text(value).font(.app(15, .semibold)).foregroundColor(.white)
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
                .font(.app(15, .bold)).foregroundColor(Brand.textPrimary)
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
                    .clipShape(Circle())
                Text(title)
                    .font(.app(11, .medium))
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

    // MARK: - Settlement account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settlement Account")
                .font(.app(15, .bold)).foregroundColor(Brand.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: "building.columns")
                    .font(.system(size: 16))
                    .foregroundColor(Brand.purple)
                    .frame(width: 42, height: 42)
                    .background(Brand.purpleLight)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("IMB Business Account")
                        .font(.app(14, .semibold)).foregroundColor(Brand.textPrimary)
                    Text(store.accountNumber.map(spacedOut) ?? "—")
                        .font(.app(13)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                if let number = store.accountNumber {
                    Button {
                        UIPasteboard.general.string = number
                        toastMsg = "Account number copied"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15))
                            .foregroundColor(Brand.purple)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy account number")
                }
            }

            if WalletFmt.parse(store.wallet?.activated_at) != nil {
                Text("Activated \(WalletFmt.day(store.wallet?.activated_at))")
                    .font(.app(12)).foregroundColor(Brand.textSecondary)
            }

            Button { router.presented = .finances } label: {
                Text("View statement")
                    .font(.app(14, .semibold))
                    .foregroundColor(Brand.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Brand.purple, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .card(padding: 14)
    }

    /// Groups an 11-digit account number as 462 103 060 83 so it can be read back aloud.
    private func spacedOut(_ number: String) -> String {
        var out = ""
        for (i, ch) in number.enumerated() {
            if i > 0 && i % 3 == 0 { out.append(" ") }
            out.append(ch)
        }
        return out
    }

    // MARK: - Recent transactions

    private var transactionsCard: some View {
        ListCard(title: "Recent Transactions", actionTitle: "View all",
                 action: { router.presented = .finances }) {
            if store.transactions.isEmpty {
                emptyLine("No transactions yet.")
            } else {
                // Grouped under date headers as it is laid out: the list arrives flat
                // and newest-first, and a run of bare timestamps reads as a log.
                VStack(spacing: 0) {
                    ForEach(Array(store.transactions.enumerated()), id: \.offset) { idx, t in
                        let day = WalletFmt.dayHeader(t.date)
                        if idx == 0 || day != WalletFmt.dayHeader(store.transactions[idx - 1].date) {
                            dayHeader(day)
                        } else {
                            Divider()
                        }
                        transactionRow(t)
                    }
                }
            }
        }
    }

    private func dayHeader(_ label: String) -> some View {
        Text(label.uppercased())
            .font(.app(11, .bold))
            .kerning(0.6)
            .foregroundColor(Brand.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }

    private func transactionRow(_ t: DashWalletTxnDTO) -> some View {
        // The API sends no description, only a signed amount — so the sign is the only
        // thing that says which way the money went.
        let value = Double(t.amount ?? "0") ?? 0
        let incoming = value >= 0
        let tone = incoming ? Brand.success : Brand.danger
        // Pale tile behind a saturated glyph — both opaque, so the icon reads clearly
        // whatever the row happens to sit on.
        let tile = incoming ? Brand.successBg : Brand.dangerBg
        return HStack(spacing: 12) {
            Image(systemName: incoming ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tone)
                .frame(width: 38, height: 38)
                .background(tile)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(incoming ? "Money in" : "Money out")
                    .font(.app(14, .semibold)).foregroundColor(Brand.textPrimary)
                // The date is already on the group header above, so the row shows the time.
                Text(WalletFmt.time(t.date) ?? "—")
                    .font(.app(12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(incoming ? "+" : "−")R\(WalletFmt.decimal(abs(value)))")
                    .font(.app(14, .bold)).foregroundColor(tone)
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
                    .font(.app(17, .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                if store.debitAvailable {
                    Button { showDebitOrder = true } label: {
                        Label("New", systemImage: "plus")
                            .font(.app(13, .semibold))
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
                .font(.app(12)).foregroundColor(Brand.textSecondary)
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
                        .font(.app(14, .semibold)).foregroundColor(Brand.textPrimary)
                    Text(r.scheduleLabel)
                        .font(.app(12)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(r.money)
                        .font(.app(14, .bold)).foregroundColor(Brand.textPrimary)
                    StatusBadge(text: r.statusLabel, fg: r.statusTone.fg, bg: r.statusTone.bg)
                }
            }
            // A failed instruction is only useful if it says why IMB refused it.
            if r.isFailed, let reason = r.last_error, !reason.isEmpty {
                Text(reason)
                    .font(.app(11)).foregroundColor(Brand.danger)
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
            .font(.app(13)).foregroundColor(Brand.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }
}
