import SwiftUI
import SafariServices

extension Notification.Name {
    /// Posted by `AnokiXTraderApp.onOpenURL` when PayCloud redirects back to
    /// `anokix://topup-return` after a wallet top-up.
    static let topupReturned = Notification.Name("anokix.topup.returned")
}

// MARK: - In-app browser

/// `SFSafariViewController` in SwiftUI clothing.
///
/// The PayCloud checkout opens here rather than in a `WKWebView`: card details are being
/// typed, so the trader must be able to see the real address bar and padlock — and 3-D
/// Secure step-ups and Safari's autofill only work properly in the real browser.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(Brand.purple)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Wraps a URL so it can drive `.sheet(item:)`.
struct CheckoutLink: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Top up

/// Top up the anokiX wallet with a card, through PayCloud's Hosted Checkout.
///
/// The flow, and why it is shaped this way:
/// 1. The trader picks an amount and we POST `api/common/topup/create`, which returns a
///    `pay_url` and our own `merchant_order_no`.
/// 2. `pay_url` opens in `SafariView` (see above).
/// 3. PayCloud redirects back to `anokix://topup-return` when it is done; the app's
///    `onOpenURL` closes the browser sheet and hands control back here.
/// 4. This sheet then polls `api/common/topup/status`. **The redirect proves nothing** —
///    the wallet is credited by PayCloud's signed webhook, verified server-side, so the
///    poll is the only thing that can say the money arrived. That is also why it keeps
///    polling if the redirect never happens and the trader closes the browser by hand.
///
/// `status=paid` means only that the card was taken. The money is in the wallet when
/// `credit_status=credited`, and that is the only state reported as success.
@MainActor
struct TopUpSheet: View {
    /// Where PayCloud sends the browser back to (registered in Info.plist).
    static let returnURL = "anokix://topup-return"

    /// Server-side bounds for a top-up (api/common/topup/create).
    private static let minAmount: Double = 1
    private static let maxAmount: Double = 500_000

    /// The quick-pick amounts, matching the trader portal.
    private static let presets = [50, 100, 200, 500, 1000]

    /// How often to re-check a top-up that has not settled yet, and for how long.
    private static let pollInterval: UInt64 = 4
    private static let pollWindow: TimeInterval = 10 * 60

    /// Called once money has actually landed, so the wallet can reload.
    let onCredited: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var amount = ""
    @State private var starting = false
    @State private var formError: String?

    /// Non-nil once a checkout has been started — the key for polling its status.
    @State private var merchantOrderNo: String?
    @State private var checkoutURL: URL?
    @State private var checkout: CheckoutLink?
    @State private var startedAmount: Double = 0

    @State private var phase: Phase = .form
    @State private var checking = false
    @State private var statusError: String?
    @State private var pollTask: Task<Void, Never>?

    private enum Phase {
        case form, waiting, paid, credited, dead
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if phase == .form { formBody } else { waitBody }
                }
                .padding(18)
            }
            .background(Brand.background)
            .navigationTitle("Top up your wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { finish() }.foregroundColor(Brand.textSecondary)
                }
            }
        }
        .sheet(item: $checkout) { link in SafariView(url: link.url).ignoresSafeArea() }
        // Back from the checkout page (or from anywhere else): the status may have moved
        // on while we were in the background, so ask straight away.
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active { Task { await checkStatus(manual: false) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .topupReturned)) { _ in
            checkout = nil
            Task { await checkStatus(manual: false) }
        }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: Amount form

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add money to your anokiX wallet with a card. You will be taken to our secure PayCloud checkout to complete the payment.")
                .font(.app(13))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.presets, id: \.self) { preset in
                        // Typing an amount by hand clears the chip, so the two can never
                        // disagree about what is about to be charged.
                        FilterChip(label: "R\(preset)",
                                   selected: Double(preset) == parsed) {
                            amount = String(preset)
                            formError = nil
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Amount (ZAR)")
                    .font(.app(13, .medium))
                    .foregroundColor(Brand.textSecondary)
                TextField("R 0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.app(18, .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .padding(14)
                    .background(Brand.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("Between R\(WalletFmt.decimal(Self.minAmount)) and R\(WalletFmt.decimal(Self.maxAmount)).")
                    .font(.app(11))
                    .foregroundColor(Brand.textTertiary)
            }

            if let formError {
                Label(formError, systemImage: "exclamationmark.circle")
                    .font(.app(12))
                    .foregroundColor(Brand.danger)
            }

            Button {
                Task { await startCheckout() }
            } label: {
                HStack(spacing: 8) {
                    if starting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "creditcard")
                    }
                    Text(starting ? "Please wait…" : "Proceed to payment")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(starting)
        }
    }

    // MARK: Waiting on the payment

    private var waitBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    switch phase {
                    case .credited:
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.success)
                    case .dead:
                        Image(systemName: "xmark.circle.fill").foregroundColor(Brand.danger)
                    default:
                        ProgressView().tint(Brand.purple)
                    }
                }
                .font(.system(size: 22))
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(waitTitle)
                        .font(.app(15, .semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text(waitMessage)
                        .font(.app(13))
                        .foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()

            if let merchantOrderNo {
                Text("Order \(merchantOrderNo)")
                    .font(.app(11))
                    .foregroundColor(Brand.textTertiary)
            }

            if let statusError {
                Text(statusError).font(.app(12)).foregroundColor(Brand.danger)
            }

            switch phase {
            case .credited:
                Button("Done") { finish() }.buttonStyle(PrimaryButtonStyle())
            case .dead:
                Button("Start a new top-up") { resetToForm() }.buttonStyle(PrimaryButtonStyle())
            default:
                if phase == .waiting, let checkoutURL {
                    Button("Open the payment page again") {
                        checkout = CheckoutLink(url: checkoutURL)
                    }
                    .font(.app(14, .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                }
                Button(checking ? "Please wait…" : "Check payment status") {
                    Task { await checkStatus(manual: true) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(checking)
            }
        }
    }

    private var waitTitle: String {
        switch phase {
        case .paid:     return "Payment received"
        case .credited: return "Wallet topped up"
        case .dead:     return "Payment not completed"
        default:        return "Waiting for your payment"
        }
    }

    private var waitMessage: String {
        switch phase {
        case .paid:
            // The card went through but the webhook has not landed yet. Keep the spinner
            // running — the wallet is seconds away, and saying "done" now would be a lie.
            return "PayCloud has taken the payment. Your wallet is being credited — this usually takes a few seconds."
        case .credited:
            return "R\(WalletFmt.decimal(startedAmount)) is now in your wallet."
        case .dead:
            return "This top-up was not completed, so nothing has been taken. You can start a new one."
        default:
            return "Finish the payment in the browser. This screen updates on its own once it goes through."
        }
    }

    // MARK: Actions

    private var parsed: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "R", with: "")
            .trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private func startCheckout() async {
        let value = parsed
        guard !amount.trimmingCharacters(in: .whitespaces).isEmpty else {
            formError = "Enter an amount to top up."
            return
        }
        guard value >= Self.minAmount else {
            formError = "The smallest top-up is R\(WalletFmt.decimal(Self.minAmount))."
            return
        }
        guard value <= Self.maxAmount else {
            formError = "The largest top-up is R\(WalletFmt.decimal(Self.maxAmount))."
            return
        }
        formError = nil
        starting = true
        defer { starting = false }

        do {
            // Send the amount to two decimals, so what the trader sees on the PayCloud
            // page is exactly what they entered here.
            let created = try await APIClient.shared.createTopup(
                amount: String(format: "%.2f", value), returnUrl: Self.returnURL)
            guard created.isUsable, let url = created.checkoutURL else {
                formError = "Could not start the top-up."
                return
            }
            merchantOrderNo = created.merchant_order_no
            checkoutURL = url
            startedAmount = created.amount ?? value
            phase = .waiting
            checkout = CheckoutLink(url: url)
            startPolling()
        } catch {
            formError = (error as? LocalizedError)?.errorDescription
                ?? "Could not start the top-up."
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        let deadline = Date().addingTimeInterval(Self.pollWindow)
        pollTask = Task {
            while !Task.isCancelled && Date() < deadline {
                try? await Task.sleep(nanoseconds: Self.pollInterval * 1_000_000_000)
                if Task.isCancelled { return }
                await checkStatus(manual: false)
                if phase == .credited || phase == .dead { return }
            }
        }
    }

    private func checkStatus(manual: Bool) async {
        guard let merchantOrderNo, !checking,
              phase == .waiting || phase == .paid else { return }
        checking = true
        defer { checking = false }

        do {
            let status = try await APIClient.shared.getTopupStatus(merchantOrderNo: merchantOrderNo)
            statusError = nil
            if status.isCredited {
                startedAmount = status.amount ?? startedAmount
                phase = .credited
                pollTask?.cancel()
                checkout = nil
                onCredited()
            } else if status.isDead {
                phase = .dead
                pollTask?.cancel()
                checkout = nil
            } else if status.isPaidNotCredited {
                phase = .paid
            }
        } catch {
            // Only speak up when the trader asked — the background ticks stay quiet so a
            // blip does not paint an error over a payment that is still going fine.
            if manual {
                statusError = (error as? LocalizedError)?.errorDescription
                    ?? "Could not check the payment. Try again in a moment."
            }
        }
    }

    private func resetToForm() {
        pollTask?.cancel()
        merchantOrderNo = nil
        checkoutURL = nil
        amount = ""
        statusError = nil
        phase = .form
    }

    private func finish() {
        pollTask?.cancel()
        dismiss()
    }
}

// MARK: - New debit order

/// Authorise IMB to debit the trader's own wallet — once off, or monthly between two
/// dates (POST api/common/debit-requests).
///
/// The account being debited is resolved server-side from the caller's active wallet, so
/// nothing on this form identifies an account: a merchant can only ever debit themselves.
/// The account number in the intro is there to say which wallet it will hit, not to pick
/// one.
///
/// The amount and reference bounds come from the `limits` block on the list call rather
/// than being hard-coded, so the form follows the server if those ever move.
@MainActor
struct DebitOrderSheet: View {
    let accountNumber: String?
    let limits: DebitLimitsDTO
    /// Called with the server's own wording once the instruction is accepted.
    let onCreated: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var onceOff = true
    @State private var amount = ""
    @State private var reference = ""
    // iOS's compact date picker has no empty state — it always shows a day — so these
    // start on a sensible pair rather than nil. What the trader sees is what gets sent.
    @State private var firstDate = Date()
    @State private var lastDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var submitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(intro)
                        .font(.app(13))
                        .foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    schedulepicker
                    amountField
                    referenceField
                    if !onceOff { dateFields }

                    Text(onceOff
                         ? "One debit will be raised against your wallet."
                         : "IMB debits your wallet monthly, from the first date up to and including the last.")
                        .font(.app(12))
                        .foregroundColor(Brand.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.app(12))
                            .foregroundColor(Brand.danger)
                    }

                    Button(submitting ? "Please wait…" : "Authorise debit order") {
                        Task { await submit() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(submitting)
                }
                .padding(18)
            }
            .background(Brand.background)
            .navigationTitle("New debit order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(Brand.textSecondary)
                }
            }
        }
    }

    private var intro: String {
        guard let accountNumber, !accountNumber.isEmpty else {
            return "Authorise IMB to debit your wallet. A once-off debit is collected once; a monthly debit is collected every month between the dates you choose."
        }
        return "Authorise IMB to debit your wallet (account \(accountNumber)). A once-off debit is collected once; a monthly debit is collected every month between the dates you choose."
    }

    // MARK: Fields

    private var schedulepicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How often")
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            HStack(spacing: 3) {
                segment("Once-off", selected: onceOff) { onceOff = true }
                segment("Monthly", selected: !onceOff) { onceOff = false }
            }
            .padding(3)
            .background(Brand.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func segment(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.app(14, .semibold))
                .foregroundColor(selected ? .white : Brand.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Brand.purple : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var amountField: some View {
        LabeledField(title: "Amount (ZAR)", text: $amount,
                     placeholder: "R 0.00", keyboard: .decimalPad)
    }

    private var referenceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Reference")
                    .font(.app(13, .medium))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                Text("\(reference.count) / \(limits.maxReference)")
                    .font(.app(12))
                    .foregroundColor(Brand.textTertiary)
            }
            TextField("e.g. Stock float", text: $reference)
                .font(.app(15))
                .foregroundColor(Brand.textPrimary)
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                // The reference is printed on the debit itself and the bank truncates it,
                // so the limit is enforced as you type rather than rejected after the fact.
                .onChange(of: reference) { value in
                    if value.count > limits.maxReference {
                        reference = String(value.prefix(limits.maxReference))
                    }
                }
        }
    }

    private var dateFields: some View {
        HStack(alignment: .top, spacing: 12) {
            datePicker("First debit date", selection: $firstDate, floor: Date())
            // The last date's calendar starts at the first, so an out-of-order pair
            // cannot be chosen in the first place.
            datePicker("Last debit date", selection: $lastDate, floor: firstDate)
        }
        // Moving the start past the end would leave an impossible pair on screen.
        .onChange(of: firstDate) { newValue in
            if lastDate < newValue { lastDate = newValue }
        }
    }

    private func datePicker(_ title: String, selection: Binding<Date>, floor: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            DatePicker("", selection: selection, in: floor..., displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Brand.purple)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Submit

    private func submit() async {
        let value = Double(amount.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "R", with: "")
            .trimmingCharacters(in: .whitespaces)) ?? 0
        guard !amount.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Enter the amount to debit."
            return
        }
        guard value >= limits.minAmount else {
            error = "The smallest debit order is R\(WalletFmt.decimal(limits.minAmount))."
            return
        }
        guard value <= limits.maxAmount else {
            error = "The largest debit order is R\(WalletFmt.decimal(limits.maxAmount))."
            return
        }
        let ref = reference.trimmingCharacters(in: .whitespaces)
        guard !ref.isEmpty else {
            error = "Enter a reference — it shows on the debit."
            return
        }

        var first: String?
        var last: String?
        if !onceOff {
            guard lastDate >= Calendar.current.startOfDay(for: firstDate) else {
                error = "The last debit date must be on or after the first."
                return
            }
            first = WalletFmt.apiDay(firstDate)
            last = WalletFmt.apiDay(lastDate)
        }

        error = nil
        submitting = true
        defer { submitting = false }

        do {
            let (_, message) = try await APIClient.shared.createDebitRequest(
                amount: String(format: "%.2f", value), reference: ref, onceOff: onceOff,
                nextDebitDate: first, finalDebitDate: last)
            onCreated(message)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not create the debit order."
        }
    }
}
