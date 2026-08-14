import SwiftUI
import UIKit

/// Airtime & VAS (Limes, live). Mirrors the web portal and the Android `AirtimeActivity`:
/// a KPI strip and an explainer that always stay on screen, then one of six sections at a
/// time —
/// 1. **Onboard customer** — register an end-customer in the Limes CRM
/// 2. **Customers** — who you have onboarded, with their Limes account no.
/// 3. **Subscription** — assign a SIM; Limes hands back the phone number
/// 4. **Catalog & orders** — sell a catalog product to a number
/// 5. **Dynamic services** — compose an exact-value bundle
/// 6. **Recent transactions** — the VAS history + KPI figures
///
/// Only onboarding + subscription need each other; airtime and data top-ups go straight to
/// any number that is already active on the network.
///
/// Limes issues its token per customer, so Subscription, Catalog & orders and Dynamic
/// services run behind the shared "Acting as" bar: nothing on those three tabs is shown or
/// called until one of the trader's active customers has been authenticated, and every
/// request they then make carries that `customer_id`.
struct AirtimeView: View {
    @StateObject private var store = VasStore()
    @State private var toastMsg: String?

    private let statCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statStrip
                howItWorks
                tabStrip
                if store.tab.isCustomerScoped {
                    ActingAsBar(store: store)
                }
                section
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if !store.transactionsLoaded { await store.loadTransactions() } }
        .refreshable { await store.loadTransactions() }
        // Surface a failed call as a toast, then clear it so it shows only once.
        .onChange(of: store.error) { message in
            guard let message else { return }
            toastMsg = message
            store.error = nil
        }
        .toast($toastMsg)
    }

    // MARK: Header

    private var statStrip: some View {
        LazyVGrid(columns: statCols, spacing: 12) {
            StatTile(label: "VAS sales · today", value: VasFormat.money(store.summary?.sales_today ?? 0),
                     icon: "chart.line.uptrend.xyaxis", iconTint: Brand.purple)
            StatTile(label: "Transactions · today", value: "\(Int(store.summary?.count_today ?? 0))",
                     icon: "arrow.left.arrow.right", iconTint: Brand.info)
            StatTile(label: "Commission · month",
                     value: VasFormat.money(store.summary?.commission_month ?? 0),
                     icon: "percent", iconTint: Brand.success)
            StatTile(label: "Wallet balance",
                     value: VasFormat.money(store.summary?.wallet_balance ?? 0),
                     icon: "wallet.pass.fill", iconTint: Brand.warning)
        }
    }

    /// The explainer the portal keeps above the tabs: what order the six steps go in.
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How this page works")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Text("**Onboard customer** → activate their SIM under **Subscription** (you hand in "
                 + "the SIM's ICCID; Limes hands back the phone number) → then sell airtime, "
                 + "data & bundles to that number under **Catalog & orders** or **Dynamic "
                 + "services**, and track it all under **Recent transactions**. Airtime & data "
                 + "top-ups go straight to any active number — onboarding is only needed when "
                 + "signing a customer up to a SIM subscription.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.infoBg.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.info.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Six labels never fit across a phone, so the pills scroll horizontally and the chosen
    /// one is brought to the leading edge.
    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VasTab.allCases) { tab in
                        Button {
                            store.tab = tab
                            withAnimation { proxy.scrollTo(tab.id, anchor: .leading) }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(tab == store.tab ? Brand.success : Brand.textSecondary)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(tab == store.tab ? Brand.successBg : Brand.surface)
                                .overlay(Capsule().stroke(
                                    tab == store.tab ? Brand.success : Brand.border, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(tab.id)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var section: some View {
        // A scoped tab shows the gate card instead of its panel until Limes has approved
        // the customer, so a selected-but-locked section stays hidden.
        if store.tab.isCustomerScoped && !store.hasActingCustomer {
            gateCard
        } else {
            switch store.tab {
            case .onboard:      VasOnboardSection(store: store)
            case .customers:    VasCustomersSection(store: store)
            case .subscription: VasSubscriptionSection(store: store)
            case .catalog:      VasCatalogSection(store: store)
            case .dynamic:      VasDynamicSection(store: store)
            case .transactions: VasTransactionsSection(store: store)
            }
        }
    }

    private var gateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select a customer above to continue", systemImage: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("Limes authenticates as the customer, so every call on this tab runs on "
                 + "their token.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if store.customersLoaded && store.activeCustomers.isEmpty {
                Divider().padding(.vertical, 2)
                Text("No customers yet. Limes issues its token per customer, so onboard "
                     + "someone before selling to them.")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Onboard a customer") { store.tab = .onboard }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Acting as

/// The bar shared by Subscription, Catalog & orders and Dynamic services. Only customers
/// with status ACT are offered — Limes refuses to authenticate as anyone else — and the
/// approved `customer_id` then travels with every request those tabs make.
private struct ActingAsBar: View {
    @ObservedObject var store: VasStore
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Acting as")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)
                if !store.actingSubject.isEmpty {
                    StatusBadge(text: store.actingSubject, fg: Brand.success, bg: Brand.successBg)
                }
                Spacer(minLength: 0)
                if store.actingCustomer != nil {
                    // There is nothing to release until a customer has been approved.
                    Button {
                        store.clearActingCustomer()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Brand.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop acting as this customer")
                }
            }

            Button { showPicker = true } label: {
                HStack(spacing: 8) {
                    Text(store.actingCustomer?.pickerLabel ?? "Select a customer")
                        .font(.system(size: 15))
                        .foregroundColor(store.actingCustomer == nil
                                         ? Brand.textTertiary : Brand.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if store.actingBusy {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Brand.textSecondary)
                    }
                }
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(store.actingBusy)

            if store.actingCustomer == nil {
                Text(store.actingBusy
                     ? "Authenticating with Limes…"
                     : "Pick a customer — their Limes token is what these calls use.")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .task { if !store.customersLoaded { await store.loadActiveCustomers() } }
        .sheet(isPresented: $showPicker) {
            SelectOptionsSheet(title: "Choose a customer",
                               options: store.activeCustomers.map { ($0.id, $0.pickerLabel) },
                               selection: selectionBinding)
        }
    }

    /// `SelectOptionsSheet` writes the picked id; selecting one runs `select-customer`.
    private var selectionBinding: Binding<String> {
        Binding(
            get: { store.actingCustomerId },
            set: { id in
                guard let customer = store.activeCustomers.first(where: { $0.id == id }) else { return }
                Task { await store.selectActingCustomer(customer) }
            })
    }
}

// MARK: - Recent transactions

/// The VAS history behind the KPI figures. Always available — it is not customer-scoped.
struct VasTransactionsSection: View {
    @ObservedObject var store: VasStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent VAS transactions")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            if store.transactions.isEmpty {
                VasEmptyCard(text: "No transactions yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(store.transactions) { txn in
                        let style = VasFormat.statusStyle(txn.status)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(txn.name ?? "—")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Brand.textPrimary)
                                    .lineLimit(1)
                                Text("\(VasFormat.msisdn(txn.msisdn)) · \(VasFormat.time(txn.created_at))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Brand.textSecondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(VasFormat.money(txn.amount))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Brand.textPrimary)
                                StatusBadge(text: style.label, fg: style.fg, bg: style.bg)
                            }
                        }
                        .card()
                    }
                }
            }
        }
    }
}

// MARK: - Shared section pieces

/// The empty-state card every VAS section uses.
struct VasEmptyCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Brand.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .card()
    }
}

/// Card header used at the top of each section: a title and the sentence explaining it.
struct VasSectionHeader: View {
    let title: String
    let body_: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Text(body_)
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Outlined input box used across the VAS forms.
struct VasFieldBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Labelled single-line VAS input.
struct VasField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var autocapitalize: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalize ? .words : .never)
                .autocorrectionDisabled(!autocapitalize)
                .foregroundColor(Brand.textPrimary)
                .modifier(VasFieldBox())
        }
    }
}

/// Labelled tap-to-select VAS dropdown, backed by the house options sheet.
struct VasPicker: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: String
    var placeholder: String = "Select"
    @State private var show = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            Button { show = true } label: {
                HStack(spacing: 8) {
                    Text(currentLabel.isEmpty ? placeholder : currentLabel)
                        .font(.system(size: 14))
                        .foregroundColor(currentLabel.isEmpty ? Brand.textTertiary : Brand.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.textSecondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Brand.surfaceVariant)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $show) {
                SelectOptionsSheet(title: title, options: options, selection: $selection)
            }
        }
    }

    private var currentLabel: String {
        options.first { $0.0 == selection }?.1 ?? ""
    }
}

/// The long-message sheet: Limes' replies name the reason (e.g. "not an active subscriber")
/// and are worth reading in full, so they get a scrollable, selectable body rather than a
/// one-line alert.
struct VasMessageSheet: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Brand.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Brand.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

/// Identifiable wrapper so a long message can drive a `.sheet(item:)`.
struct VasMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}
