import SwiftUI

/// Airtime & VAS › Customers. The end-customers this trader has onboarded, with the Limes
/// account number to quote when activating their SIM on the Subscription tab.
struct VasCustomersSection: View {
    @ObservedObject var store: VasStore

    private static let limit = 500

    @State private var search = ""
    @State private var customers: [VasCustomerDTO] = []
    @State private var loading = false
    @State private var loaded = false
    /// The keyword the list on screen was fetched with — an empty result means different
    /// things for "nothing matched" and "nobody onboarded yet".
    @State private var appliedSearch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VasSectionHeader(
                title: "Onboarded customers",
                body_: "Customers you've registered with Limes. Use the account number when "
                     + "activating their SIM on the Subscription tab.")

            HStack(spacing: 10) {
                TextField("Search name, ID, phone, email or account no.", text: $search)
                    .font(.app(14))
                    .foregroundColor(Brand.textPrimary)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await load() } }
                    .modifier(VasFieldBox())

                Button("Search") { Task { await load() } }
                    .font(.app(13, .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Brand.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
            }

            HStack {
                Text(countLabel)
                    .font(.app(12))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                Button("Refresh") { Task { await load() } }
                    .font(.app(13, .semibold))
                    .foregroundColor(Brand.purple)
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if customers.isEmpty {
                VasEmptyCard(text: appliedSearch.isEmpty
                             ? "No customers onboarded yet. Add one on the Onboard customer tab."
                             : "No customers match that search.")
            } else {
                VStack(spacing: 8) {
                    ForEach(customers) { customer in
                        CustomerRow(customer: customer)
                    }
                }
            }
        }
        .card()
        // Loads once when the tab is first opened; later visits reuse what is on screen,
        // and an onboard invalidates it so the new customer appears straight away.
        .task { if !loaded || !store.customersLoaded { await load() } }
    }

    private var countLabel: String {
        let n = customers.count
        return "\(n) \(n == 1 ? "customer" : "customers")"
    }

    /// The Customers tab lists everyone this trader has onboarded, whatever their Limes
    /// status — only the "Acting as" picker is restricted to the active ones.
    private func load() async {
        loading = true
        loaded = true
        let keyword = search.trimmed
        do {
            let data = try await APIClient.shared.getVasCustomers(
                search: keyword, limit: Self.limit, activeOnly: false)
            customers = data.customers
            appliedSearch = keyword
        } catch {
            customers = []
            appliedSearch = keyword
            store.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your customers."
        }
        loading = false
    }
}

private struct CustomerRow: View {
    let customer: VasCustomerDTO

    var body: some View {
        let status = VasFormat.limesStatusStyle(customer.status)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Text(customer.displayName)
                    .font(.app(15, .semibold))
                    .foregroundColor(Brand.textPrimary)
                Spacer(minLength: 8)
                StatusBadge(text: status.label, fg: status.fg, bg: status.bg)
            }
            Text(metaLine)
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
            if let email = customer.email, !email.isEmpty {
                Text(email)
                    .font(.app(12))
                    .foregroundColor(Brand.textSecondary)
                    .lineLimit(1)
            }
            if let account = customer.limes_account_id, !account.isEmpty {
                Text("Account no. \(account)")
                    .font(.app(11, .semibold))
                    .foregroundColor(Brand.purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var metaLine: String {
        var parts: [String] = []
        if let id = customer.id_number, !id.isEmpty { parts.append(id) }
        let phone = VasFormat.msisdn(customer.phone)
        if !phone.isEmpty { parts.append(phone) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
