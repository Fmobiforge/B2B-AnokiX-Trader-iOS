import SwiftUI

/// POS "Current Sale" / Complete Sale (Pagamio). Review lines (qty steppers + remove),
/// apply a discount, pick a payment method, and complete the sale. VAT (15%) is
/// extracted from the inclusive total.
///
/// The four payment methods split into two flows:
/// - **Cash, Wallet, QR Payment** — recorded straight away through
///   `api/trader/pos/sale` with the matching `payment_method`; the receipt sheet
///   mirrors the portal's Sale Recorded modal.
/// - **Card** — the money is taken on a physical card machine, so nothing is recorded
///   here. The trader's terminals are read from `api/common/pos/terminals`, they pick
///   one, and the amount is pushed to it via `api/common/pos/payments`
///   (`CardMachineSheet`). The backend records that sale when the gateway reports the
///   card payment.
struct CheckoutView: View {
    @EnvironmentObject var cart: Cart
    @Environment(\.dismiss) private var dismiss
    @State private var discountText = ""
    @State private var payment: PosPayment = .wallet
    @State private var submitting = false
    @State private var receipt: PosSaleDTO?
    @State private var errorMsg: String?
    @State private var cardMachines: [PosTerminalDTO] = []
    @State private var showCardMachines = false
    /// Card-machine problems get their own alert — "Sale failed" would be wrong
    /// wording for "no machine is switched on".
    @State private var cardMachineMsg: String?
    /// Set when the sheet reports a successful send, read by its `onDismiss`.
    @State private var paymentSentToMachine = false
    @State private var showPaymentPicker = false

    /// `SelectOptionsSheet` stores the raw key, so bridge it back to the enum.
    private var paymentSelection: Binding<String> {
        Binding(get: { payment.rawValue },
                set: { payment = PosPayment(rawValue: $0) ?? payment })
    }

    private var inclusive: Double { cart.subtotal }
    private var discount: Double { min(max(0, Double(discountText) ?? 0), inclusive) }
    private var total: Double { max(0, inclusive - discount) }
    private var vat: Double { total * 0.15 / 1.15 }
    private var subtotalExcl: Double { total - vat }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line items with qty steppers + remove
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Current Sale")
                    if cart.isEmpty {
                        Text("Your cart is empty. Add products to start a sale.")
                            .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(cart.lines) { line in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                        Text("\(Money.rand(line.unitPrice)) each").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                        Text(Money.rand(line.lineTotal)).font(.system(size: 13, weight: .bold)).foregroundColor(Brand.purple)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 6) {
                                        Button { cart.remove(line.id) } label: {
                                            Image(systemName: "trash").foregroundColor(Brand.danger).font(.system(size: 15))
                                        }
                                        QtyStepper(qty: line.qty,
                                                   dec: { cart.setQty(line.id, line.qty - 1) },
                                                   inc: { cart.setQty(line.id, line.qty + 1) })
                                    }
                                }
                                .padding(.vertical, 10)
                                if line.id != cart.lines.last?.id { Divider() }
                            }
                        }
                    }
                }
                .card()

                // Discount + totals
                VStack(spacing: 10) {
                    HStack {
                        Text("Discount").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                        Spacer()
                        TextField("0", text: $discountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 90, height: 36)
                            .padding(.horizontal, 10)
                            .background(Brand.surfaceVariant)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Divider()
                    totalRow("Subtotal (excl. VAT)", Money.rand(subtotalExcl))
                    totalRow("VAT (15%)", Money.rand(vat))
                    Divider()
                    HStack {
                        Text("Total").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text(Money.rand(total)).font(.system(size: 18, weight: .bold)).foregroundColor(Brand.purple)
                    }
                }
                .card()

                // Payment method — a `SelectOptionsSheet`, not a native `Menu`. A Menu
                // pop-up is drawn in its own UIKit context that ignores the screen's
                // pinned light scheme, so in system Dark Mode its rows came out
                // near-white over the light backdrop and were unreadable. The sheet
                // draws its own rows in explicit Brand colours instead.
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Payment Method")
                    Button { showPaymentPicker = true } label: {
                        HStack {
                            Text(payment.label).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        }
                        .padding(.horizontal, 14).frame(height: 48)
                        .background(Brand.surfaceVariant)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .card()

                Button(submitting ? "Processing…" : "Complete Sale · \(Money.rand(total))") {
                    Task { await completeSale() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(cart.isEmpty || submitting)
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Current Sale")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaymentPicker) {
            SelectOptionsSheet(title: "Payment Method",
                               options: PosPayment.allCases.map { ($0.rawValue, $0.label) },
                               selection: paymentSelection)
        }
        .sheet(item: $receipt) { sale in
            PosReceiptView(sale: sale) {
                cart.clear()
                receipt = nil
                dismiss()
            }
        }
        .sheet(isPresented: $showCardMachines, onDismiss: {
            // Runs once the sheet is fully gone, so popping the till here cannot race
            // the sheet's own dismissal.
            guard paymentSentToMachine else { return }
            paymentSentToMachine = false
            // The amount is on the machine and the backend owns the rest of that
            // sale, so the till is finished with it — clear and step back.
            cart.clear()
            dismiss()
        }) {
            CardMachineSheet(amount: total,
                             amountText: Money.rand(total),
                             description: saleDescription,
                             machines: cardMachines) {
                paymentSentToMachine = true
                showCardMachines = false
            }
        }
        .alert("Sale failed", isPresented: .constant(errorMsg != nil)) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
        .alert("Card machine payment", isPresented: .constant(cardMachineMsg != nil)) {
            Button("OK") { cardMachineMsg = nil }
        } message: {
            Text(cardMachineMsg ?? "")
        }
    }

    private func completeSale() async {
        guard !cart.isEmpty, !submitting else { return }
        if payment == .card {
            await startCardMachinePayment()
        } else {
            await recordSale()
        }
    }

    // MARK: Card — pay on a card machine

    /// Load the trader's card machines, then offer them. The list is fetched per sale
    /// rather than cached, so a machine switched on (or off) since the last sale is
    /// reflected without the cashier having to restart anything.
    private func startCardMachinePayment() async {
        submitting = true
        do {
            let data = try await APIClient.shared.getPosTerminals()
            let machines = data.active
            if machines.isEmpty {
                // "None set up" and "all switched off" are different problems, and
                // only the trader can tell them apart from the wording.
                cardMachineMsg = data.configured
                    ? "None of your card machines are active right now. Switch one on and try again."
                    : "No card machines are set up for your store yet. Add one in the trader portal to take card payments."
            } else {
                cardMachines = machines
                showCardMachines = true
            }
        } catch {
            cardMachineMsg = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your card machines."
        }
        submitting = false
    }

    /// What the payment is for, worded as the portal does it: "Sale · 3 items".
    private var saleDescription: String {
        let count = cart.itemCount
        return "Sale · \(count) \(count == 1 ? "item" : "items")"
    }

    // MARK: Cash / Wallet / QR — record the sale

    private func recordSale() async {
        submitting = true
        let items: [[String: Any]] = cart.lines.map {
            ["product_id": Int($0.id) ?? 0, "quantity": $0.qty, "unit_price": $0.unitPrice]
        }
        do {
            let sale = try await APIClient.shared.createPosSale(
                items: items, paymentMethod: payment.rawValue, discount: discount)
            receipt = sale
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? "Failed to complete sale."
        }
        submitting = false
    }

    private func totalRow(_ l: String, _ r: String) -> some View {
        HStack {
            Text(l).font(.system(size: 14)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(r).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
        }
    }
}

private struct QtyStepper: View {
    let qty: Int
    let dec: () -> Void
    let inc: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: dec) { Image(systemName: "minus.circle.fill").foregroundColor(Brand.textTertiary) }
            Text("\(qty)").font(.system(size: 15, weight: .bold)).frame(minWidth: 20)
            Button(action: inc) { Image(systemName: "plus.circle.fill").foregroundColor(Brand.purple) }
        }
    }
}

// MARK: - Card machine payment (mirrors POS_Sale_LetUserChooseTerminal.png)

/// Pushes a POS sale total to one of the trader's PayCloud terminals via
/// `api/common/pos/payments`.
///
/// The sheet's job ends at "the amount is on the machine" — the customer still has to
/// tap or insert their card there, and the backend records the sale once the gateway
/// reports it, so this never claims the customer has paid.
///
/// Failures are shown in the sheet rather than as an alert, because the gateway's
/// wording is the actionable part ("[E07507]The device is not turned on, please start
/// the device and cashier application") and it is usually fixable on the spot — so
/// Send stays available for a retry once the trader has switched the terminal on.
struct CardMachineSheet: View {
    let amount: Double
    let amountText: String
    let description: String
    let machines: [PosTerminalDTO]
    /// Called after a successful send, once the trader taps Done.
    let onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var sending = false
    /// True once the amount is on a machine — Send must not fire a second payment.
    @State private var sent = false
    @State private var status: StatusLine?
    @State private var showMachinePicker = false

    private struct StatusLine {
        let text: String
        let ok: Bool
    }

    /// Guarded rather than force-indexed: the caller only ever passes a non-empty
    /// list, but a crash at the till would be a poor way to find that out.
    private var selected: PosTerminalDTO? {
        machines.indices.contains(index) ? machines[index] : machines.first
    }

    /// `SelectOptionsSheet` stores a String key, so address machines by their id.
    private var machineSelection: Binding<String> {
        Binding(get: { selected.map { String($0.id) } ?? "" },
                set: { key in
                    guard let i = machines.firstIndex(where: { String($0.id) == key }) else { return }
                    index = i
                    // A different machine deserves a clean slate — the previous
                    // machine's error says nothing about this one.
                    status = nil
                })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Card machine payment")
                    .font(.system(size: 19, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.textSecondary)
                }
            }
            .padding(.bottom, 16)

            // Amount being pushed to the machine
            HStack {
                Text("Amount").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text(amountText).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
            .padding(16)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Card machine")
                .font(.system(size: 13, weight: .bold)).foregroundColor(Brand.textPrimary)
                .padding(.top, 16).padding(.bottom, 8)

            // A `SelectOptionsSheet` rather than a native `Menu`, for the same reason
            // as the payment-method field above: a Menu pop-up ignores this screen's
            // pinned light scheme and renders unreadably in system Dark Mode.
            Button { showMachinePicker = true } label: {
                HStack {
                    Text(selected?.displayName ?? "")
                        .font(.system(size: 14)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                }
                .padding(.horizontal, 14).frame(height: 48)
                .background(Brand.surfaceVariant)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(sending || sent)

            if let status {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: status.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(status.ok ? Brand.success : Brand.danger)
                    Text(status.text)
                        .font(.system(size: 13))
                        .foregroundColor(status.ok ? Brand.success : Brand.danger)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.top, 14)
            }

            // Stacked full-width rather than a side-by-side row: the Send label carries
            // the amount, so a row clips it on a narrow screen, at a large Dynamic Type
            // size, or simply on a bigger sale. Full width also gives the one action
            // that moves money the tap target it deserves.
            VStack(spacing: 10) {
                // Once sent, Done takes over the primary button: it is the only action
                // left, so leaving it as the quieter of the two would read as the lesser
                // of a choice that no longer exists.
                Button {
                    // After a send it is the parent that closes the sheet (and then the
                    // till), so Done hands off rather than dismissing here.
                    if sent { onSent() } else { Task { await send() } }
                } label: {
                    HStack(spacing: 8) {
                        if !sent {
                            Image(systemName: "creditcard.fill").font(.system(size: 15))
                        }
                        Text(sent ? "Done" : (sending ? "Sending…" : "Send \(amountText)"))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(sending || selected == nil)
                .opacity(sending ? 0.6 : 1)

                if !sent {
                    Button { dismiss() } label: {
                        Text("Close")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Brand.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                    }
                }
            }
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(20)
        // Self-styled sheet drawn on an explicit opaque Brand background + forced light
        // scheme, matching SelectOptionsSheet and the app's other pickers. Without this
        // the sheet inherited a clear backing and the Current Sale screen showed straight
        // through it. .large stays available because a gateway error can run to several
        // lines and must not be clipped behind the buttons.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showMachinePicker) {
            SelectOptionsSheet(title: "Card machine",
                               options: machines.map { (String($0.id), $0.displayName) },
                               selection: machineSelection)
        }
    }

    private func send() async {
        guard let terminal = selected, !sending, !sent else { return }
        sending = true
        status = nil
        do {
            try await APIClient.shared.sendPosPayment(
                amount: amount, terminalId: terminal.id,
                description: description, referenceType: "pos_sale")
            sent = true
            status = StatusLine(
                text: "Sent to \(terminal.displayName). Ask the customer to complete the payment on the card machine.",
                ok: true)
        } catch {
            status = StatusLine(
                text: (error as? LocalizedError)?.errorDescription
                    ?? "Could not send the payment to the card machine.",
                ok: false)
        }
        sending = false
    }
}
