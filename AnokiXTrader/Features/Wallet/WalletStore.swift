import SwiftUI

// MARK: - Debit orders (GET/POST api/common/debit-requests)

/// Envelope `data` for the debit orders standing against the trader's own IMB wallet,
/// newest first, plus the rules the create form must respect.
///
/// A debit order authorises IMB to pull money INTO the wallet from the merchant's bank
/// account. The account debited is resolved server-side from the caller's active wallet,
/// so a merchant can only ever debit themselves.
struct DebitRequestsData: Decodable {
    let debit_requests: [DebitRequestDTO]?
    /// False when the IMB payment rail is not configured — the create form is then closed.
    let available: Bool?
    /// Nil until the wallet is active.
    let account_number: String?
    let limits: DebitLimitsDTO?

    var rows: [DebitRequestDTO] { debit_requests ?? [] }
    var isAvailable: Bool { available ?? true }
    /// Fallback bounds for when the API sends no `limits` block.
    var bounds: DebitLimitsDTO { limits ?? DebitLimitsDTO() }
}

/// Amount / reference bounds the create form validates against.
struct DebitLimitsDTO: Decodable {
    let min_amount: Double?
    let max_amount: Double?
    let max_reference: Int?

    init(min_amount: Double? = nil, max_amount: Double? = nil, max_reference: Int? = nil) {
        self.min_amount = min_amount
        self.max_amount = max_amount
        self.max_reference = max_reference
    }

    var minAmount: Double { (min_amount ?? 0) > 0 ? min_amount! : 1 }
    var maxAmount: Double { (max_amount ?? 0) > 0 ? max_amount! : 500_000 }
    var maxReference: Int { (max_reference ?? 0) > 0 ? max_reference! : 20 }
}

struct DebitRequestDTO: Decodable, Identifiable, Hashable {
    let id: Int
    /// Shows on the debit itself. Max 20 characters.
    let reference: String?
    let account_number: String?
    let amount: Double
    let currency: String?
    /// True = collected once; false = collected monthly between the two dates.
    let once_off: Bool?
    /// "once-off" | "monthly" | "completed".
    let schedule: String?
    /// "yyyy-MM-dd". Nil on a once-off.
    let next_debit_date: String?
    /// "yyyy-MM-dd". Nil on a once-off.
    let final_debit_date: String?
    /// "pending" | "active" | "failed" — "active" means IMB accepted the instruction.
    let status: String?
    let imb_request_id: String?
    let imb_status: String?
    /// Why IMB declined, on a failed row.
    let last_error: String?
    /// "dd/MM/yyyy HH:mm:ss".
    let created_at: String?

    private enum CodingKeys: String, CodingKey {
        case id, reference, account_number, amount, currency, once_off, schedule
        case next_debit_date, final_debit_date, status, imb_request_id, imb_status
        case last_error, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        reference = try? c.decode(String.self, forKey: .reference)
        account_number = try? c.decode(String.self, forKey: .account_number)
        // Money arrives as a number here but as a string elsewhere in this API, so both.
        if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = d
        } else if let s = try? c.decode(String.self, forKey: .amount), let d = Double(s) {
            amount = d
        } else {
            amount = 0
        }
        currency = try? c.decode(String.self, forKey: .currency)
        once_off = try? c.decode(Bool.self, forKey: .once_off)
        schedule = try? c.decode(String.self, forKey: .schedule)
        next_debit_date = try? c.decode(String.self, forKey: .next_debit_date)
        final_debit_date = try? c.decode(String.self, forKey: .final_debit_date)
        status = try? c.decode(String.self, forKey: .status)
        imb_request_id = try? c.decode(String.self, forKey: .imb_request_id)
        imb_status = try? c.decode(String.self, forKey: .imb_status)
        last_error = try? c.decode(String.self, forKey: .last_error)
        created_at = try? c.decode(String.self, forKey: .created_at)
    }

    // MARK: Derived

    var isOnceOff: Bool { once_off ?? ((schedule ?? "") == "once-off") }
    var isFailed: Bool { (status ?? "").lowercased() == "failed" }

    var statusLabel: String {
        let s = status ?? ""
        guard !s.isEmpty else { return "—" }
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    var statusTone: (fg: Color, bg: Color) {
        switch (status ?? "").lowercased() {
        case "active": return (Brand.success, Brand.successBg)
        case "failed": return (Brand.danger, Brand.dangerBg)
        default:       return (Brand.warning, Brand.warningBg)   // "pending" and anything new
        }
    }

    /// "Once-off · Raised 18 Aug 2026, 18:23" / "Monthly · 19 Aug 2026 to 27 Aug 2026".
    var scheduleLabel: String {
        if (schedule ?? "").lowercased() == "completed" { return "Completed" }
        if isOnceOff {
            let raised = WalletFmt.dateTime(created_at)
            return raised.isEmpty ? "Once-off" : "Once-off · Raised \(raised)"
        }
        return "Monthly · \(WalletFmt.day(next_debit_date)) to \(WalletFmt.day(final_debit_date))"
    }

    /// Debit orders carry an ISO code ("ZAR"); everything else on this screen shows "R".
    var money: String {
        let code = (currency ?? "").uppercased()
        let symbol = (code.isEmpty || code == "ZAR") ? "R" : code + " "
        return symbol + WalletFmt.decimal(amount)
    }
}

// MARK: - Top-up (PayCloud Hosted Checkout)

/// POST api/common/topup/create.
///
/// Every field is decoded defensively and `amount` accepts a number or a string. This
/// endpoint starts a payment, so a shape the app did not expect must degrade to "we
/// could not start the top-up" rather than throwing halfway through the flow.
struct TopupCreateDTO: Decodable {
    /// Our own order reference; the key for polling `TopupStatusDTO`.
    let merchant_order_no: String?
    /// The PayCloud checkout page to open in the browser.
    let pay_url: String?
    let amount: Double?
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case merchant_order_no, pay_url, amount, currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        merchant_order_no = try? c.decode(String.self, forKey: .merchant_order_no)
        pay_url = try? c.decode(String.self, forKey: .pay_url)
        amount = TopupCreateDTO.flexDouble(c, .amount)
        currency = try? c.decode(String.self, forKey: .currency)
    }

    /// Decode a money field that may arrive as a JSON string or number.
    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>,
                                     _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }

    var checkoutURL: URL? {
        guard let pay_url, !pay_url.isEmpty else { return nil }
        return URL(string: pay_url)
    }

    var isUsable: Bool {
        checkoutURL != nil && !(merchant_order_no ?? "").isEmpty
    }
}

/// GET api/common/topup/status?merchant_order_no=…
struct TopupStatusDTO: Decodable {
    let merchant_order_no: String?
    /// PayCloud's own reference, once they have one.
    let trade_no: String?
    let amount: Double?
    let currency: String?
    /// "pending" | "paid" | "failed" | "cancelled".
    let status: String?
    /// "none" | "pending" | "credited" | "failed".
    let credit_status: String?
    let credited_at: String?
    let created_at: String?

    private enum CodingKeys: String, CodingKey {
        case merchant_order_no, trade_no, amount, currency, status
        case credit_status, credited_at, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        merchant_order_no = try? c.decode(String.self, forKey: .merchant_order_no)
        trade_no = try? c.decode(String.self, forKey: .trade_no)
        if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = d
        } else if let s = try? c.decode(String.self, forKey: .amount) {
            amount = Double(s)
        } else {
            amount = nil
        }
        currency = try? c.decode(String.self, forKey: .currency)
        status = try? c.decode(String.self, forKey: .status)
        credit_status = try? c.decode(String.self, forKey: .credit_status)
        credited_at = try? c.decode(String.self, forKey: .credited_at)
        created_at = try? c.decode(String.self, forKey: .created_at)
    }

    private var creditKey: String { (credit_status ?? "").lowercased() }
    private var statusKey: String { (status ?? "").lowercased() }

    /// The money is in the wallet.
    var isCredited: Bool { creditKey == "credited" }

    /// Card taken but the wallet has not been credited yet — keep waiting.
    var isPaidNotCredited: Bool {
        statusKey == "paid" && !isCredited && creditKey != "failed"
    }

    /// Nothing more will happen to this order.
    var isDead: Bool {
        statusKey == "failed" || statusKey == "cancelled" || creditKey == "failed"
    }
}

// MARK: - Store

/// Backs the Wallet tab. Two calls, deliberately kept apart because they fail apart:
/// `api/common/wallet` for the live balance, `api/common/debit-requests` for the standing
/// instructions. A wallet that is not active still has debit orders worth showing, and
/// IMB being down for a balance read must not blank the rest of the page.
@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var wallet: DashWalletDTO?
    @Published private(set) var debit: DebitRequestsData?
    @Published private(set) var loading = false
    @Published private(set) var refreshing = false
    @Published var error: String?

    /// Hidden with the eye button; not persisted, it is a shoulder-surfing guard.
    @Published var balancesHidden = false

    /// Anything that should show the balance card's spinner.
    var busy: Bool { loading || refreshing }

    var balance: DashWalletBalanceDTO? { wallet?.balance }
    var isActive: Bool { (wallet?.status ?? "").lowercased() == "active" }
    var accountNumber: String? {
        let fromDebit = debit?.account_number
        if let fromDebit, !fromDebit.isEmpty { return fromDebit }
        let fromWallet = wallet?.account_number
        return (fromWallet?.isEmpty == false) ? fromWallet : nil
    }
    var transactions: [DashWalletTxnDTO] { balance?.transactions ?? [] }
    var debitOrders: [DebitRequestDTO] { debit?.rows ?? [] }
    var debitAvailable: Bool { debit?.isAvailable ?? true }

    var statusLabel: String {
        let s = wallet?.status ?? ""
        guard !s.isEmpty else { return "" }
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// "as of 02:22", plus a staleness warning: a degraded balance read still returns a
    /// number, and the trader needs to know that number may have moved on.
    var asOfLabel: String? {
        guard let raw = balance?.as_of, let time = WalletFmt.time(raw), !time.isEmpty else { return nil }
        return (balance?.stale == true) ? "as of \(time) · balance may be out of date" : "as of \(time)"
    }

    func load() async {
        loading = true
        await loadWallet(refresh: false)
        await loadDebitOrders()
        loading = false
    }

    /// The manual refresh button bypasses the server's balance cache — the point of
    /// pressing it is to see money that has only just arrived.
    func refreshBalance() async {
        guard !refreshing else { return }
        refreshing = true
        await loadWallet(refresh: true)
        refreshing = false
    }

    func loadWallet(refresh: Bool) async {
        do {
            wallet = try await APIClient.shared.getWallet(refresh: refresh)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your wallet."
        }
    }

    /// A failure here is silent: the balance above is the point of the screen, and a
    /// failed debit-order read leaves that perfectly readable.
    func loadDebitOrders() async {
        debit = try? await APIClient.shared.getDebitRequests()
    }

    /// Money on the purple card, or a mask when balances are hidden. Everything on that
    /// card goes through here, so the eye button cannot leave one figure showing.
    func cardMoney(_ value: Double?) -> String {
        balancesHidden ? "R●●●●●●" : "R" + WalletFmt.decimal(value ?? 0)
    }
}

// MARK: - Formatting

/// The wallet's own date shapes: ISO-8601 with an offset on balances and transactions,
/// "dd/MM/yyyy HH:mm:ss" on debit-order creation, "yyyy-MM-dd" on debit dates.
enum WalletFmt {
    static func decimal(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: value)) ?? "0.00"
    }

    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }

    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        for pattern in ["yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss",
                        "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd"] {
            if let d = formatter(pattern).date(from: raw) { return d }
        }
        return nil
    }

    /// "2026-08-10T18:32:41+02:00" → "18:32" in the phone's own zone.
    static func time(_ raw: String?) -> String? {
        guard let d = parse(raw) else { return nil }
        return formatter("HH:mm").string(from: d)
    }

    /// → "10 Aug 2026, 18:32". Empty when nothing parses.
    static func dateTime(_ raw: String?) -> String {
        guard let d = parse(raw) else { return "" }
        return formatter("dd MMM yyyy, HH:mm").string(from: d)
    }

    /// "2026-08-19" → "19 Aug 2026". Falls back to the raw value.
    static func day(_ raw: String?) -> String {
        guard let d = parse(raw) else { return raw ?? "—" }
        return formatter("dd MMM yyyy").string(from: d)
    }

    /// The API's date format for both debit dates.
    static func apiDay(_ date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }
}
