import SwiftUI

/// Airtime & VAS › Subscription. Assigns a SIM to a subscription product; Limes replies with
/// the MSISDN, which is the number every later top-up is sold to. eSIMs carry no printed
/// serial, so switching eSIM on hides the ICCID field and sends `e_sim=1`.
struct VasSubscriptionSection: View {
    @ObservedObject var store: VasStore

    @State private var products: [VasSubscriptionProductDTO] = []
    @State private var productId = ""
    @State private var iccid = ""
    @State private var eSim = false
    @State private var subscriptions: [VasSubscriptionDTO] = []
    @State private var submitting = false
    @State private var loaded = false
    @State private var loadedForCustomer = ""
    @State private var success = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VasSectionHeader(
                title: "Assign a SIM & subscription",
                body_: "Pick a subscription product and hand in the SIM's ICCID. Limes assigns "
                     + "the phone number (MSISDN) — that number, not the ICCID, is what you "
                     + "recharge under Catalog & orders.")

            VasPicker(title: "Product",
                      options: products.map { ($0.id, $0.label) },
                      selection: $productId,
                      placeholder: "Select a product")

            Toggle(isOn: $eSim) {
                Text("eSIM")
                    .font(.app(14, .medium))
                    .foregroundColor(Brand.textPrimary)
            }
            .tint(Brand.purple)

            // An eSIM has no ICCID to hand in — hide the field rather than ask for a serial
            // that does not exist.
            if !eSim {
                VStack(alignment: .leading, spacing: 5) {
                    VasField(title: "ICCID (SIM)", text: $iccid,
                             placeholder: "8927078220001234567",
                             keyboard: .numberPad, autocapitalize: false)
                    Text("The 19–20 digit serial printed on the SIM card — not a phone number.")
                        .font(.app(11))
                        .foregroundColor(Brand.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(submitting ? "Processing…" : "Create subscription") { subscribe() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(submitting)
                .opacity(submitting ? 0.6 : 1)

            Divider().padding(.vertical, 2)

            Text("Activated SIMs")
                .font(.app(15, .bold))
                .foregroundColor(Brand.textPrimary)

            if subscriptions.isEmpty {
                Text("No SIMs activated yet.")
                    .font(.app(12))
                    .foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(subscriptions) { sub in
                        let status = VasFormat.limesStatusStyle(sub.status)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.numberLabel)
                                    .font(.app(15, .semibold))
                                    .foregroundColor(sub.hasNumber ? Brand.textPrimary : Brand.warning)
                                Text(sub.metaLabel)
                                    .font(.app(12))
                                    .foregroundColor(Brand.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            StatusBadge(text: status.label, fg: status.fg, bg: status.bg)
                        }
                        .padding(12)
                        .background(Brand.surfaceVariant)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .card()
        // The products and activated SIMs are read on the acting customer's token, so a
        // different customer means everything on screen is dropped and re-read.
        .task(id: store.actingCustomerId) { await loadIfNeeded() }
        .alert("Subscription created", isPresented: $success) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The SIM has been submitted for activation. The assigned number appears "
                 + "under Activated SIMs.")
        }
    }

    // MARK: Data

    private func loadIfNeeded() async {
        let customerId = store.actingCustomerId
        guard !customerId.isEmpty else { return }
        guard !loaded || loadedForCustomer != customerId else { return }
        loaded = true
        loadedForCustomer = customerId
        products = []
        productId = ""
        iccid = ""
        subscriptions = []
        await loadProducts(customerId)
        await loadSubscriptions(customerId)
    }

    private func loadProducts(_ customerId: String) async {
        do {
            let data = try await APIClient.shared.getVasSubscriptionProducts(customerId: customerId)
            products = data.products
            // Default to the first product so the form is usable in one tap.
            if productId.isEmpty, let first = products.first { productId = first.id }
        } catch {
            store.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load the subscription products."
        }
    }

    private func loadSubscriptions(_ customerId: String) async {
        do {
            subscriptions = try await APIClient.shared
                .getVasSubscriptions(customerId: customerId).subscriptions
        } catch {
            subscriptions = []
        }
    }

    // MARK: Create

    private func subscribe() {
        guard !productId.isEmpty else {
            store.error = "Please select a subscription product."
            return
        }
        if !eSim && !isValidIccid(iccid) {
            store.error = "Enter the SIM's ICCID (19–20 digits), or switch on eSIM."
            return
        }
        let customerId = store.actingCustomerId
        guard !customerId.isEmpty else {
            store.error = "Choose the customer you are acting for first."
            return
        }

        submitting = true
        Task {
            do {
                try await APIClient.shared.subscribeVas(
                    productId: productId, iccid: iccid.trimmed, eSim: eSim, customerId: customerId)
                iccid = ""
                success = true
                await loadSubscriptions(customerId)
            } catch {
                store.error = (error as? LocalizedError)?.errorDescription
                    ?? "Could not create the subscription."
            }
            submitting = false
        }
    }

    /// ICCIDs printed on SA SIMs are 19–20 digits — a phone number pasted here is a typo.
    private func isValidIccid(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        return digits.count >= 18 && digits.count <= 22
    }
}
