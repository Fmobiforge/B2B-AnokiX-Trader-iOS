import SwiftUI
import SwiftyJSON

// MARK: - VAS DTOs (the customer / subscription / dynamic half of api/common/vas/*)
//
// Built with SwiftyJSON `init(json:)` like the catalog DTOs in DTOs.swift — the VAS feed
// mixes numbers and numeric strings across ids and amounts, and SwiftyJSON's `*Value`
// accessors coerce either way.

/// `data` of GET api/common/vas/customers — end-customers onboarded into Limes.
struct VasCustomersData {
    let customers: [VasCustomerDTO]
    let total: Int

    init(json: JSON) {
        customers = (json["customers"].array ?? []).map(VasCustomerDTO.init(json:))
        total = json["total"].intValue
    }
}

struct VasCustomerDTO: Identifiable, Hashable {
    let id: String
    let limes_account_id: String?
    let title: String?
    let firstname: String?
    let lastname: String?
    let id_type: String?
    let id_number: String?
    let email: String?
    let phone: String?
    let city: String?
    let status: String?
    let created_at: String?

    init(json: JSON) {
        id = json["id"].stringValue
        limes_account_id = json["limes_account_id"].string
        title = json["title"].string
        firstname = json["firstname"].string
        lastname = json["lastname"].string
        id_type = json["id_type"].string
        id_number = json["id_number"].string
        email = json["email"].string
        phone = json["phone"].string
        city = json["city"].string
        status = json["status"].string
        created_at = json["created_at"].string
    }

    /// "Mr Tam Ho" — title is optional, so it is only prefixed when present.
    var displayName: String {
        let parts = [title, firstname, lastname]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }

    /// Limes only authenticates as a customer whose account is live.
    var isActive: Bool {
        let s = (status ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        return s == "ACT" || s == "ACTIVE"
    }

    /// "Mr Tam Ho · 023 123 1132" — name plus the number, as on the web portal.
    var pickerLabel: String {
        let formatted = VasFormat.msisdn(phone)
        return formatted.isEmpty ? displayName : "\(displayName) · \(formatted)"
    }

    static func == (lhs: VasCustomerDTO, rhs: VasCustomerDTO) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// `data` of POST api/common/vas/onboard-customer. The endpoint upserts by ID number, so a
/// retry reports `already_exists` rather than failing.
struct VasOnboardCustomerData {
    let alreadyExists: Bool

    init(json: JSON) {
        alreadyExists = json["customer"]["already_exists"].boolValue
    }
}

/// `data` of POST api/common/vas/onboard-customer/preview — the exact request the real
/// onboard would send to Limes, built by the same server-side code but not dispatched.
struct VasOnboardPreviewData {
    let method: String
    let endpoint: String
    let baseURL: String
    let headers: [String]
    let body: JSON

    init(json: JSON) {
        method = json["method"].string ?? "POST"
        endpoint = json["endpoint"].stringValue
        baseURL = json["base_url"].stringValue
        headers = (json["headers"].array ?? []).map { $0.stringValue }
        body = json["body"]
    }

    /// The whole preview rendered as the text the sheet shows.
    var rendered: String {
        var out = "\(method) \(baseURL)\(endpoint)\n"
        for header in headers { out += header + "\n" }
        out += "\n"
        out += body.rawString(options: [.prettyPrinted, .sortedKeys]) ?? "{}"
        return out
    }
}

/// `data` of POST api/common/vas/select-customer. Limes issues its token per customer, so the
/// three scoped tabs first authenticate as the customer being served; `subject` is the Limes
/// login that answered and is what the "Acting as" chip shows once approved.
struct VasSelectCustomerData {
    let authenticated: Bool
    let subject: String?
    let customerId: String?
    let email: String?

    init(json: JSON) {
        authenticated = json["authenticated"].boolValue
        subject = json["subject"].string
        customerId = json["customer"]["id"].string
        email = json["customer"]["email"].string
    }

    /// The chip label: the Limes subject when it came back, otherwise the customer's email.
    var subjectLabel: String {
        if let subject, !subject.trimmingCharacters(in: .whitespaces).isEmpty {
            return subject.trimmingCharacters(in: .whitespaces)
        }
        if let email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            return email.trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}

/// `data` of GET api/common/vas/subscription-products — the SIM subscription products the
/// "Assign a SIM" form offers. `inHand` products take an ICCID and activate immediately;
/// the rest are "on order" and activate on delivery.
struct VasSubscriptionProductsData {
    let configured: Bool
    let products: [VasSubscriptionProductDTO]

    init(json: JSON) {
        configured = json["configured"].boolValue
        products = (json["products"].array ?? []).map(VasSubscriptionProductDTO.init(json:))
    }
}

struct VasSubscriptionProductDTO: Identifiable, Hashable {
    let id: String
    let name: String?
    let sku: String?
    let description: String?
    let inHand: Bool
    let category: String?

    init(json: JSON) {
        id = json["id"].stringValue
        name = json["name"].string
        sku = json["sku"].string
        description = json["description"].string
        inHand = json["inHand"].boolValue
        category = json["category"].string
    }

    /// "Mobile Contract Package · SIM in hand" — what the product picker shows.
    var label: String {
        let base = (name?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (id.isEmpty ? "—" : id)
        return base + (inHand ? " · SIM in hand" : " · SIM on order")
    }

    static func == (lhs: VasSubscriptionProductDTO, rhs: VasSubscriptionProductDTO) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// `data` of GET api/common/vas/subscriptions — the SIMs this merchant has activated.
/// `msisdn` may be nil: Limes allocates the number from a tenant pool and reports it once,
/// so a SIM activated while that pool was empty has none until a sync.
struct VasSubscriptionsData {
    let subscriptions: [VasSubscriptionDTO]

    init(json: JSON) {
        subscriptions = (json["subscriptions"].array ?? []).map(VasSubscriptionDTO.init(json:))
    }
}

struct VasSubscriptionDTO: Identifiable, Hashable {
    let id: String
    let iccid: String?
    let msisdn: String?
    let status: String?
    let created_at: String?

    init(json: JSON) {
        id = json["id"].stringValue
        iccid = json["iccid"].string
        msisdn = json["msisdn"].string
        status = json["status"].string
        created_at = json["created_at"].string
    }

    var hasNumber: Bool { !(msisdn ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

    /// The number leads the row — that, not the ICCID, is what later top-ups are sold to.
    var numberLabel: String {
        hasNumber ? VasFormat.msisdn(msisdn) : "Number pending"
    }

    var metaLabel: String {
        let serial = (iccid ?? "").trimmingCharacters(in: .whitespaces)
        return serial.isEmpty ? "eSIM" : "ICCID \(serial)"
    }

    static func == (lhs: VasSubscriptionDTO, rhs: VasSubscriptionDTO) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Formatting

/// South-African money/number formatting for the VAS screens — space-grouped thousands and
/// a comma decimal, e.g. `R 5 050,00`, matching the web portal's "Order summary".
enum VasFormat {
    private static let za = Locale(identifier: "en_ZA")

    static func money(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = za
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return "R " + (f.string(from: NSNumber(value: value)) ?? "0,00")
    }

    static func money(_ value: String?) -> String { money(parse(value)) }

    /// Lenient number parse for API strings and free-text input that may be nil, blank or
    /// non-numeric. A lone comma is treated as the decimal separator, because the SA locale
    /// writes "10,50" and the numeric keyboard offers whichever the device is set to.
    static func parse(_ value: String?) -> Double {
        guard var raw = value?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return 0 }
        if raw.contains(",") && !raw.contains(".") {
            raw = raw.replacingOccurrences(of: ",", with: ".")
        }
        return Double(raw) ?? 0
    }

    /// 27821234567 / 0821234567 → "082 123 4567" when it resolves to a 10-digit local
    /// number; anything else is handed back untouched.
    static func msisdn(_ raw: String?) -> String {
        guard let raw else { return "" }
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("27") && digits.count == 11 {
            digits = "0" + digits.dropFirst(2)
        }
        guard digits.count == 10 else { return raw }
        let a = digits.prefix(3)
        let b = digits.dropFirst(3).prefix(3)
        let c = digits.dropFirst(6)
        return "\(a) \(b) \(c)"
    }

    /// Space-grouped byte count for the Dynamic services "= N bytes" hint.
    static func bytes(_ value: Int64) -> String {
        let f = NumberFormatter()
        f.locale = za
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// "dd/MM/yyyy HH:mm:ss" → "HH:mm" for the transactions list.
    static func time(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "dd/MM/yyyy HH:mm:ss"
        guard let d = parser.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "HH:mm"
        return out.string(from: d)
    }

    /// True for a SA mobile number as 10 digits (0xxxxxxxxx) or 11 digits (27xxxxxxxxx).
    static func isValidMsisdn(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        return (digits.count == 10 && digits.hasPrefix("0"))
            || (digits.count == 11 && digits.hasPrefix("27"))
    }

    /// Status pill label + colours for a VAS transaction, mirroring the Android `styleStatus`.
    static func statusStyle(_ status: String?) -> (label: String, fg: Color, bg: Color) {
        let s = (status ?? "").lowercased()
        if s.contains("fail") || s.contains("error") || s.contains("declin") {
            return ("Failed", Brand.danger, Brand.dangerBg)
        }
        if s.contains("success") || s.contains("complete") || s.contains("paid") {
            return ("Success", Brand.success, Brand.successBg)
        }
        let raw = status ?? ""
        let label = raw.isEmpty ? "Pending" : raw.prefix(1).uppercased() + raw.dropFirst()
        return (label, Brand.purple, Brand.purpleLight)
    }

    /// Limes status codes: ACT is live, anything else is still pending or suspended.
    static func limesStatusStyle(_ status: String?) -> (label: String, fg: Color, bg: Color) {
        let s = (status ?? "").trimmingCharacters(in: .whitespaces)
        let active = s.caseInsensitiveCompare("ACT") == .orderedSame
            || s.caseInsensitiveCompare("ACTIVE") == .orderedSame
        return (s.isEmpty ? "—" : s.uppercased(),
                active ? Brand.success : Brand.warning,
                active ? Brand.successBg : Brand.warningBg)
    }
}

/// Maps Limes VAS leaf categories to SF Symbols, keyed off the category id/name (the API
/// carries no artwork). Mirrors the Android `VasIcons` and the web portal's glyphs.
enum VasIcons {
    static func icon(for id: String?, _ name: String?) -> String {
        let key = ((id ?? "") + " " + (name ?? "")).lowercased()
        if key.contains("whatsapp") || key.contains("sms") || key.contains("message") {
            return "message.fill"
        }
        if key.contains("data") || key.contains("fwa") || key.contains("wifi") { return "wifi" }
        if key.contains("voice") || key.contains("airtime") || key.contains("call") {
            return "phone.fill"
        }
        if key.contains("service") || key.contains("fee") || key.contains("wallet") {
            return "creditcard.fill"
        }
        let bundleKeys = ["combo", "bundle", "subscription", "package", "gsm", "flte",
                          "supplementary", "choose", "recharge", "convert", "day", "week"]
        if bundleKeys.contains(where: { key.contains($0) }) { return "square.grid.2x2.fill" }
        return "antenna.radiowaves.left.and.right"
    }
}

// MARK: - Tabs

/// The six sections of the Airtime & VAS screen, in the order the web portal shows them.
enum VasTab: String, CaseIterable, Identifiable {
    case onboard = "Onboard customer"
    case customers = "Customers"
    case subscription = "Subscription"
    case catalog = "Catalog & orders"
    case dynamic = "Dynamic services"
    case transactions = "Recent transactions"

    var id: String { rawValue }

    /// The three tabs Limes runs on the customer's own token, so they need "Acting as" first.
    var isCustomerScoped: Bool {
        self == .subscription || self == .catalog || self == .dynamic
    }
}

// MARK: - Store

/// Shared state for the Airtime & VAS screen: the KPI/transaction feed that is always on
/// screen, and the "Acting as" customer the three scoped tabs run on.
@MainActor
final class VasStore: ObservableObject {
    private static let txnPerPage = 20
    private static let customerLimit = 500

    // Header
    @Published private(set) var summary: VasSummaryDTO?
    @Published private(set) var transactions: [VasTransactionDTO] = []
    @Published private(set) var transactionsLoaded = false

    // Acting as
    @Published private(set) var activeCustomers: [VasCustomerDTO] = []
    @Published private(set) var actingCustomer: VasCustomerDTO?
    @Published private(set) var actingSubject = ""
    @Published private(set) var actingBusy = false
    @Published private(set) var customersLoaded = false

    @Published var tab: VasTab = .onboard
    @Published var error: String?

    /// The customer every request on the three scoped tabs is made for, or "" while none has
    /// been authenticated. Sections read it at call time so they always send the current pick.
    var actingCustomerId: String { actingCustomer?.id ?? "" }
    var hasActingCustomer: Bool { !actingCustomerId.isEmpty }

    // ---- Transactions + KPI summary --------------------------------------

    func loadTransactions() async {
        do {
            let data = try await APIClient.shared.getVasTransactions(page: 1, perPage: Self.txnPerPage)
            transactions = data.transactions
            summary = data.summary
        } catch {
            transactions = []
        }
        transactionsLoaded = true
    }

    // ---- Acting as -------------------------------------------------------

    /// Only customers with status ACT are offered — Limes refuses to authenticate as anyone
    /// else. The filter is repeated on the device so a server that ignores the flag cannot
    /// offer a customer Limes would reject.
    func loadActiveCustomers() async {
        guard !actingBusy else { return }
        actingBusy = true
        do {
            let data = try await APIClient.shared.getVasCustomers(
                search: "", limit: Self.customerLimit, activeOnly: true)
            activeCustomers = data.customers.filter(\.isActive)
            customersLoaded = true
            // A customer that is no longer active must not stay selected.
            if let acting = actingCustomer, !activeCustomers.contains(where: { $0.id == acting.id }) {
                clearActingCustomer()
            }
        } catch {
            customersLoaded = false
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your customers."
        }
        actingBusy = false
    }

    /// A customer was just onboarded, so the picker list is stale. They are not active on
    /// Limes yet, but the operator will expect to find them once they are.
    func invalidateCustomers() {
        customersLoaded = false
    }

    /// Authenticate as `customer`. Approval is what unlocks the three scoped tabs; anything
    /// else leaves them shut.
    func selectActingCustomer(_ customer: VasCustomerDTO) async {
        guard !actingBusy else { return }
        actingBusy = true
        do {
            let data = try await APIClient.shared.selectVasCustomer(customerId: customer.id)
            if data.authenticated {
                actingCustomer = customer
                actingSubject = data.subjectLabel
            } else {
                clearActingCustomer()
                self.error = "Limes could not authenticate as this customer. "
                    + "Make sure their account is active, then try again."
            }
        } catch {
            clearActingCustomer()
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not authenticate as this customer."
        }
        actingBusy = false
    }

    /// Stop acting as this customer. Their token is what the three tabs run on, so letting it
    /// go locks them again — that is the point of the control.
    func clearActingCustomer() {
        actingCustomer = nil
        actingSubject = ""
    }
}
