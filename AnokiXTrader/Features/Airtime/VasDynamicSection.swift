import SwiftUI

/// Airtime & VAS › Dynamic services. Builds an exact-value bundle from one or more service
/// lines and provisions it straight onto a number — the path Limes recommends when the fixed
/// catalog cannot express the amount.
///
/// Units follow the Limes API: VOICE is minutes, SMS a message count, GPA_CREDIT Rand, and
/// DATA/WHATSAPP are *bytes*. The operator still types GB (as on the web portal) and the
/// conversion happens here, with the byte figure echoed under the field.
struct VasDynamicSection: View {
    @ObservedObject var store: VasStore

    private static let bytesPerGB: Double = 1_073_741_824

    /// The services the Limes dynamic endpoint accepts, with the unit each one is typed in.
    enum Service: String, CaseIterable, Identifiable {
        case voice = "VOICE"
        case data = "DATA"
        case sms = "SMS"
        case whatsapp = "WHATSAPP"
        case airtime = "GPA_CREDIT"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .voice:    return "Voice"
            case .data:     return "Data"
            case .sms:      return "SMS"
            case .whatsapp: return "WhatsApp"
            case .airtime:  return "Airtime credit"
            }
        }

        var amountLabel: String {
            switch self {
            case .voice:            return "Amount (minutes)"
            case .data, .whatsapp:  return "Amount (GB)"
            case .sms:              return "Amount (messages)"
            case .airtime:          return "Amount (Rand)"
            }
        }

        /// True when the typed amount is GB and must be sent to Limes as bytes.
        var inGigabytes: Bool { self == .data || self == .whatsapp }

        /// True when the unit only makes sense as a whole number (minutes, messages, bytes).
        var wholeUnits: Bool { self != .airtime }
    }

    /// One bundle line: the state the request is built from.
    struct Line: Identifiable {
        let id = UUID()
        var service: Service = .voice
        var amount = ""
        var price = ""
        var expiry: Date?

        var amountValue: Double { VasFormat.parse(amount) }
        var priceValue: Double { VasFormat.parse(price) }
        var bytesValue: Int64 { Int64((amountValue * VasDynamicSection.bytesPerGB).rounded()) }

        /// The value in the unit Limes expects: bytes for data, a whole count for minutes and
        /// messages, and the exact Rand figure for airtime credit — rounding R10,50 up to R11
        /// there would quietly sell the customer something they did not ask for.
        var apiValue: Any {
            if service.inGigabytes { return bytesValue }
            let raw = amountValue
            if !service.wholeUnits && raw != raw.rounded() { return raw }
            return Int64(raw.rounded())
        }

        /// True once this line carries an amount the API would accept.
        var hasAmount: Bool {
            if service.inGigabytes { return bytesValue > 0 }
            return amountValue > 0
        }
    }

    @State private var msisdn = ""
    @State private var lines: [Line] = [Line()]
    @State private var submitting = false
    @State private var success = false

    private static let apiDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VasSectionHeader(
                title: "Compose a custom bundle",
                body_: "Build exact-value bundles and provision them straight onto the number. "
                     + "Data is entered in GB and converted to bytes for you.")

            VasField(title: "Phone number (MSISDN)", text: $msisdn,
                     placeholder: "082 123 4567", keyboard: .phonePad, autocapitalize: false)

            Text("Bundle lines")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            ForEach($lines) { $line in
                LineCard(line: $line,
                         // A single line cannot be removed — the bundle would then have
                         // nothing to provision.
                         canRemove: lines.count > 1,
                         onRemove: { lines.removeAll { $0.id == line.id } })
            }

            Button { lines.append(Line()) } label: {
                Label("Add service", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.purple)
            }
            .buttonStyle(.plain)

            Divider()

            HStack {
                Text("Bundle total")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text(VasFormat.money(lines.reduce(0) { $0 + $1.priceValue }))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.purple)
            }

            Button(submitting ? "Processing…" : "Provision services") { provision() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(submitting)
                .opacity(submitting ? 0.6 : 1)
        }
        .card()
        .alert("Services provisioned", isPresented: $success) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your custom bundle has been submitted. Check Recent transactions for the outcome.")
        }
    }

    // MARK: Provision

    /// The `services` array of the dynamic-services request; prices go in cents.
    private func buildServices() -> [[String: Any]] {
        lines.map { line in
            var entry: [String: Any] = [
                "definitionCode": line.service.rawValue,
                "value": line.apiValue,
                "priceInCents": Int64((line.priceValue * 100).rounded()),
            ]
            if let expiry = line.expiry {
                entry["expiryDate"] = Self.apiDate.string(from: expiry)
            }
            return entry
        }
    }

    private func provision() {
        if let problem = validationProblem() {
            store.error = problem
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
                try await APIClient.shared.provisionVasDynamicServices(
                    msisdn: msisdn.trimmed, services: buildServices(), customerId: customerId)
                success = true
                await store.loadTransactions()
            } catch {
                store.error = (error as? LocalizedError)?.errorDescription
                    ?? "Could not provision the services."
            }
            submitting = false
        }
    }

    private func validationProblem() -> String? {
        let number = msisdn.trimmed
        if number.isEmpty { return "Please enter the recipient's mobile number." }
        if !VasFormat.isValidMsisdn(number) {
            return "Enter a valid mobile number, e.g. 082 123 4567."
        }
        if lines.isEmpty { return "Add at least one service line." }
        for line in lines {
            if !line.hasAmount { return "Enter an amount greater than zero for every service line." }
            if line.priceValue <= 0 { return "Enter a price greater than R0.00 for every service line." }
        }
        return nil
    }
}

// MARK: - Line card

private struct LineCard: View {
    @Binding var line: VasDynamicSection.Line
    let canRemove: Bool
    let onRemove: () -> Void

    @State private var showExpiry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(line.service.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                if canRemove {
                    Button("Remove", action: onRemove)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.danger)
                }
            }

            VasPicker(title: "Service",
                      options: VasDynamicSection.Service.allCases.map { ($0.rawValue, $0.label) },
                      selection: serviceBinding)

            VStack(alignment: .leading, spacing: 4) {
                VasField(title: line.service.amountLabel, text: $line.amount,
                         placeholder: "0", keyboard: .decimalPad, autocapitalize: false)
                if line.service.inGigabytes && line.bytesValue > 0 {
                    Text("= \(VasFormat.bytes(line.bytesValue)) bytes")
                        .font(.system(size: 11))
                        .foregroundColor(Brand.textTertiary)
                }
            }

            VasField(title: "Price (R)", text: $line.price,
                     placeholder: "R 0.00", keyboard: .decimalPad, autocapitalize: false)

            VStack(alignment: .leading, spacing: 6) {
                Text("Expires")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                Button { showExpiry = true } label: {
                    HStack {
                        Text(expiryLabel)
                            .font(.system(size: 14))
                            .foregroundColor(line.expiry == nil ? Brand.textTertiary : Brand.textPrimary)
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(Brand.textSecondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Brand.surfaceVariant)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Brand.surfaceVariant)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showExpiry) {
            // A bundle that expired yesterday cannot be provisioned, so the past is not offered.
            ExpiryPickerSheet(date: line.expiry ?? Date()) { line.expiry = $0 }
        }
    }

    private var expiryLabel: String {
        guard let expiry = line.expiry else { return "Select date" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: expiry)
    }

    private var serviceBinding: Binding<String> {
        Binding(get: { line.service.rawValue },
                set: { line.service = VasDynamicSection.Service(rawValue: $0) ?? .voice })
    }
}

/// Date sheet for a bundle line's expiry — today onwards only.
private struct ExpiryPickerSheet: View {
    @State var date: Date
    let onPick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Expires")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Brand.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Brand.purple)
                .padding(.horizontal, 12)

            Spacer(minLength: 0)

            Button("Apply") {
                onPick(date)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
    }
}
