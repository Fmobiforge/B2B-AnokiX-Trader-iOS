import SwiftUI

/// Finances screen — the trader's anokiX wallet ledger (GET api/trader/finances).
/// A horizontally-scrolling KPI strip sits above a search box, the Status / Type /
/// Payment-Method dropdowns and a date-range pill; all of these filter the loaded
/// list locally (the endpoint takes no query params). Each row opens a detail sheet
/// (View) or offers Download PDF via the ⋯ menu (placeholder — no endpoint yet).
struct FinancesView: View {
    @StateObject private var store = FinancesStore()
    @State private var showDatePicker = false
    @State private var detailTxn: FinanceTxnDTO?
    @State private var toastMsg: String?

    private let statusOptions = [("all", "All Statuses"), ("paid", "Paid"), ("pending", "Pending"),
                                 ("overdue", "Overdue"), ("partial", "Partial")]
    private let typeOptions = [("all", "All Types"), ("invoice", "Invoice"), ("payment", "Payment"),
                               ("payout", "Payout"), ("credit_note", "Credit Note")]
    private let methodOptions = [("all", "All Methods"), ("eft", "EFT"), ("card", "Card"),
                                 ("cash", "Cash"), ("credit", "Credit")]

    // Single outer ScrollView (matching InvoicesView / InventoryView, which are hosted
    // the same way): the KPI strip, filters and list scroll together. A fixed-header
    // VStack with a *nested* vertical ScrollView for the list collapsed here — the
    // nested scroll fought the tall horizontal KPI strip for vertical space.
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                statStrip
                filterBar
                Divider()
                content
            }
        }
        .background(Brand.background)
        .task { if store.all.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        .sheet(item: $detailTxn) { txn in
            FinanceDetailSheet(txn: txn) { toastMsg = "PDF download coming soon." }
        }
        .sheet(isPresented: $showDatePicker) {
            DateRangeSheet(from: store.dateFrom ?? Date(), to: store.dateTo ?? Date()) { from, to in
                store.dateFrom = from
                store.dateTo = to
            }
        }
        .toast($toastMsg)
    }

    // MARK: - KPI strip

    private var statStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                kpi("Spent (This Month)", Money.rand(store.spentMonth), "Paid this month",
                    "creditcard.fill", Brand.purple)
                kpi("Commission (This Month)", Money.rand(store.commissionMonth), "Platform fee this month",
                    "doc.text.fill", Brand.warning)
                kpi("Total Paid", Money.rand(store.totalPaid),
                    "\(store.totalCount) \(store.totalCount == 1 ? "transaction" : "transactions")",
                    "checkmark.seal.fill", Brand.success)
                kpi("Pending", Money.rand(store.pending), "Awaiting settlement",
                    "clock.fill", Brand.info)
                kpi("Failed / Reversed", Money.rand(store.failedReversed),
                    store.failedReversedCount == 0 ? "None"
                        : "\(store.failedReversedCount) \(store.failedReversedCount == 1 ? "item" : "items")",
                    "exclamationmark.circle.fill", Brand.danger)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Brand.background)
    }

    /// A KPI card mirroring the web portal: icon + label on the top row, a large
    /// value, then a subtitle. The label reserves two lines so the values stay
    /// baseline-aligned across cards regardless of label length.
    private func kpi(_ label: String, _ value: String, _ sub: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(label).font(.system(size: 12)).foregroundColor(Brand.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(Brand.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 14)
            Text(sub).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .lineLimit(1)
                .padding(.top, 4)
        }
        .frame(width: 200, alignment: .leading)
        .padding(16)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                TextField("Search reference, order, distributor…", text: $store.search)
                    .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
            }
            .padding(.horizontal, 12).frame(height: 44)
            .background(Brand.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterMenu(options: statusOptions, selection: $store.statusFilter, placeholder: "Status")
                    filterMenu(options: typeOptions, selection: $store.typeFilter, placeholder: "Type")
                    filterMenu(options: methodOptions, selection: $store.methodFilter, placeholder: "Method")
                }
            }

            dateRangePill
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 10)
        .background(Brand.surface)
    }

    private func filterMenu(options: [(String, String)], selection: Binding<String>, placeholder: String) -> some View {
        let currentLabel = options.first { $0.0 == selection.wrappedValue }?.1 ?? placeholder
        let isActive = selection.wrappedValue != "all"
        return Menu {
            ForEach(options, id: \.0) { opt in
                Button {
                    selection.wrappedValue = opt.0
                } label: {
                    if selection.wrappedValue == opt.0 {
                        Label(opt.1, systemImage: "checkmark")
                    } else {
                        Text(opt.1)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(isActive ? currentLabel : placeholder)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Brand.purple : Brand.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(Brand.textSecondary)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(isActive ? Brand.purpleLight : Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? Brand.purple : Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var dateRangePill: some View {
        HStack(spacing: 10) {
            Button { showDatePicker = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                    Text(dateLabel).font(.system(size: 13))
                        .foregroundColor(store.hasDateRange ? Brand.textPrimary : Brand.textSecondary)
                    Spacer()
                }
            }
            if store.hasDateRange {
                Button { store.clearDateRange() } label: {
                    Text("Clear").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                }
            }
        }
        .padding(.horizontal, 12).frame(height: 44)
        .background(Brand.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dateLabel: String {
        guard store.hasDateRange else { return "Date range" }
        let from = store.dateFrom.map { FinanceFmt.display($0) } ?? "…"
        let to = store.dateTo.map { FinanceFmt.display($0) } ?? "…"
        return "\(from)  →  \(to)"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.loading && store.all.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
        } else if store.filtered.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                HStack {
                    Text("Showing \(store.filtered.count) \(store.filtered.count == 1 ? "transaction" : "transactions")")
                        .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                    Spacer()
                }
                ForEach(store.filtered) { txn in
                    FinanceCard(txn: txn,
                                onView: { detailTxn = txn },
                                onDownload: { toastMsg = "PDF download coming soon." })
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "banknote")
                .font(.system(size: 44)).foregroundColor(Brand.textTertiary)
            Text("No transactions found")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
            Text("Your wallet payments will appear here. Try adjusting the filters or date range.")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
}

// MARK: - Transaction card

private struct FinanceCard: View {
    let txn: FinanceTxnDTO
    let onView: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StatusBadge(text: txn.typeLabel, fg: txn.typeTone.fg, bg: txn.typeTone.bg)
                Spacer()
                StatusBadge(text: txn.statusLabel, fg: txn.statusTone.fg, bg: txn.statusTone.bg)
            }

            HStack(alignment: .center, spacing: 10) {
                InitialBadge(text: initial(txn.counterparty), color: Brand.purple, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(txn.counterparty ?? "—")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        .lineLimit(1)
                    if let phone = txn.counterparty_phone, !phone.isEmpty {
                        Text(phone).font(.system(size: 11)).foregroundColor(Brand.textSecondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(FinanceMoney.signed(txn.amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(txn.isOutflow ? Brand.danger : Brand.success)
            }
            .padding(.top, 12)

            Text(txn.description ?? "—")
                .font(.system(size: 12)).foregroundColor(Brand.textPrimary)
                .lineLimit(2)
                .padding(.top, 10)

            Text("\(txn.shortReference) · \(FinanceFmt.date(txn.created_at))")
                .font(.system(size: 10)).foregroundColor(Brand.textTertiary)
                .padding(.top, 4)

            Divider().padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "wallet.pass").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Text(txn.methodDisplay).font(.system(size: 11)).foregroundColor(Brand.textSecondary).lineLimit(1)
                Spacer()
                Button(action: onView) {
                    Text("View").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.purple, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Menu {
                    Button { onView() } label: { Label("View details", systemImage: "eye") }
                    Button { onDownload() } label: { Label("Download PDF", systemImage: "doc.text") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.textSecondary)
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                }
            }
            .padding(.top, 12)
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture { onView() }
    }

    private func initial(_ name: String?) -> String {
        let n = (name ?? "").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "?" : String(n.prefix(1)).uppercased()
    }
}

// MARK: - Detail sheet

private struct FinanceDetailSheet: View {
    let txn: FinanceTxnDTO
    let onDownload: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        StatusBadge(text: txn.typeLabel, fg: txn.typeTone.fg, bg: txn.typeTone.bg)
                        Spacer()
                        StatusBadge(text: txn.statusLabel, fg: txn.statusTone.fg, bg: txn.statusTone.bg)
                    }

                    Text(FinanceMoney.signed(txn.amount))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(txn.isOutflow ? Brand.danger : Brand.success)
                        .padding(.top, 14)
                    Text(txn.description ?? "—")
                        .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        .padding(.top, 4)

                    Divider().padding(.vertical, 12)

                    row("Reference", txn.reference ?? "—")
                    row("Order", txn.order_number ?? "—")
                    row("Paid to", txn.counterparty ?? "—")
                    if let phone = txn.counterparty_phone, !phone.isEmpty { row("Phone", phone) }
                    row("Method", txn.methodDisplay)
                    row("Date", FinanceFmt.dateTime(txn.created_at))

                    Button(action: { dismiss(); onDownload() }) {
                        Label("Download PDF", systemImage: "doc.text")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.purple, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)
                }
                .padding(20)
            }
            .background(Brand.background)
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Signed money helper

enum FinanceMoney {
    /// Signed Rand: "-R 60.00" for outflows, "R 60.00" otherwise.
    static func signed(_ value: Double) -> String {
        (value < 0 ? "-" : "") + Money.rand(abs(value))
    }
}
