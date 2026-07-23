import SwiftUI

// MARK: - Finances DTOs (GET api/trader/finances)

/// Envelope `data` for the finances screen: the wallet ledger plus a pre-computed
/// KPI summary. The endpoint takes no query params, so filtering/searching happens
/// locally in `FinancesStore`.
struct FinancesData: Decodable {
    let transactions: [FinanceTxnDTO]
    let summary: FinanceSummaryDTO?
}

/// Pre-computed KPI totals returned alongside the list.
struct FinanceSummaryDTO: Decodable {
    let spent: Double
    let spent_month: Double
    let pending: Double
    let commission_month: Double
    let count: Int

    enum CodingKeys: String, CodingKey {
        case spent, spent_month, pending, commission_month, count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spent = FinanceSummaryDTO.flex(c, .spent)
        spent_month = FinanceSummaryDTO.flex(c, .spent_month)
        pending = FinanceSummaryDTO.flex(c, .pending)
        commission_month = FinanceSummaryDTO.flex(c, .commission_month)
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
    }

    /// Decode a money field that may arrive as a JSON string or number.
    private static func flex(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }
}

/// One ledger entry. `amount` is signed (negative = money out). Money fields may
/// arrive as strings or numbers, so they're decoded leniently.
struct FinanceTxnDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let reference: String?
    let type: String?
    let counterparty: String?
    let counterparty_phone: String?
    let order_number: String?
    let description: String?
    let amount: Double
    let currency: String?
    let status: String?
    /// Optional — the API has no method field yet (see requirements).
    let payment_method: String?
    /// "yyyy-MM-dd HH:mm:ss".
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, reference, type, counterparty, counterparty_phone
        case order_number, description, amount, currency, status, payment_method, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        reference = try c.decodeIfPresent(String.self, forKey: .reference)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        counterparty = try c.decodeIfPresent(String.self, forKey: .counterparty)
        counterparty_phone = try c.decodeIfPresent(String.self, forKey: .counterparty_phone)
        order_number = try c.decodeIfPresent(String.self, forKey: .order_number)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        amount = FinanceTxnDTO.flexDouble(c, .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        payment_method = try c.decodeIfPresent(String.self, forKey: .payment_method)
        created_at = try c.decodeIfPresent(String.self, forKey: .created_at)
    }

    /// Decode a money field that may arrive as a JSON string or number.
    static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }

    // MARK: Derived

    /// Coarse type bucket used by the Type filter (invoice/payment/payout/credit_note).
    var typeGroup: String {
        let t = (type ?? "").lowercased()
        if t.contains("invoice") { return "invoice" }
        if t.contains("payout") { return "payout" }
        if t.contains("credit") { return "credit_note" }
        return "payment"
    }

    var typeLabel: String {
        switch typeGroup {
        case "invoice":     return "Invoice"
        case "payout":      return "Payout"
        case "credit_note": return "Credit Note"
        default:            return "Payment"
        }
    }

    var typeTone: (fg: Color, bg: Color) {
        switch typeGroup {
        case "invoice":     return (Brand.info, Brand.infoBg)
        case "payout":      return (Brand.purple, Brand.purpleLight)
        case "credit_note": return (Brand.warning, Brand.warningBg)
        default:            return (Brand.success, Brand.successBg)
        }
    }

    var statusLabel: String {
        switch (status ?? "").lowercased() {
        case "paid":     return "Paid"
        case "pending":  return "Pending"
        case "overdue":  return "Overdue"
        case "partial":  return "Partial"
        case "failed":   return "Failed"
        case "reversed": return "Reversed"
        default:         return (status?.isEmpty == false) ? status!.capitalized : "—"
        }
    }

    var statusTone: (fg: Color, bg: Color) {
        switch (status ?? "").lowercased() {
        case "paid":     return (Brand.success, Brand.successBg)
        case "pending":  return (Brand.warning, Brand.warningBg)
        case "overdue":  return (Brand.danger, Brand.dangerBg)
        case "partial":  return (Brand.info, Brand.infoBg)
        case "failed":   return (Brand.danger, Brand.dangerBg)
        default:         return (Brand.textSecondary, Brand.surfaceVariant)
        }
    }

    /// Method key for the (future) Payment Method filter; nil until the API sends one.
    var methodKey: String? {
        guard let m = payment_method, !m.isEmpty else { return nil }
        return m.lowercased()
    }

    var methodDisplay: String {
        (payment_method?.isEmpty == false) ? payment_method! : "anokiX Wallet (IMB)"
    }

    var isOutflow: Bool { amount < 0 }

    /// First 8 chars of a UUID reference (matches the web portal's truncation).
    var shortReference: String {
        guard let r = reference, !r.isEmpty else { return "—" }
        return r.count > 10 ? String(r.prefix(8)) + "…" : r
    }
}

// MARK: - Store

/// Loads the wallet ledger from GET api/trader/finances and applies the search /
/// Status / Type / Payment-Method / date-range filters locally.
@MainActor
final class FinancesStore: ObservableObject {
    @Published var all: [FinanceTxnDTO] = []
    @Published var summary: FinanceSummaryDTO?
    @Published var loading = false
    @Published var error: String?

    // Filter state
    @Published var search = ""
    @Published var statusFilter = "all"
    @Published var typeFilter = "all"
    @Published var methodFilter = "all"
    @Published var dateFrom: Date?
    @Published var dateTo: Date?

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getFinances()
            all = data.transactions
            summary = data.summary
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load finances."
            all = []
            summary = nil
        }
        loading = false
    }

    /// The list after applying every active filter.
    var filtered: [FinanceTxnDTO] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return all.filter { t in
            if !q.isEmpty {
                let hay = [t.reference, t.order_number, t.counterparty, t.description, t.counterparty_phone]
                    .compactMap { $0?.lowercased() }
                if !hay.contains(where: { $0.contains(q) }) { return false }
            }
            if statusFilter != "all", (t.status ?? "").lowercased() != statusFilter { return false }
            if typeFilter != "all", t.typeGroup != typeFilter { return false }
            // Payment method has no field in the API yet — a specific pick only matches
            // once the backend supplies payment_method (methodKey is nil until then).
            if methodFilter != "all", t.methodKey != methodFilter { return false }
            if dateFrom != nil || dateTo != nil {
                guard let d = FinanceFmt.parse(t.created_at) else { return false }
                let day = Calendar.current.startOfDay(for: d)
                if let from = dateFrom, day < Calendar.current.startOfDay(for: from) { return false }
                if let to = dateTo, day > Calendar.current.startOfDay(for: to) { return false }
            }
            return true
        }
    }

    var hasDateRange: Bool { dateFrom != nil || dateTo != nil }

    func clearDateRange() {
        dateFrom = nil
        dateTo = nil
    }

    // MARK: KPI accessors

    var spentMonth: Double { summary?.spent_month ?? 0 }
    var commissionMonth: Double { summary?.commission_month ?? 0 }
    var totalPaid: Double { summary?.spent ?? 0 }
    var pending: Double { summary?.pending ?? 0 }
    var totalCount: Int { summary?.count ?? all.count }

    /// Failed/Reversed isn't in the summary — computed from the list.
    var failedReversed: Double {
        all.filter {
            let s = ($0.status ?? "").lowercased()
            return s == "failed" || s == "reversed"
        }.reduce(0) { $0 + abs($1.amount) }
    }

    var failedReversedCount: Int {
        all.filter {
            let s = ($0.status ?? "").lowercased()
            return s == "failed" || s == "reversed"
        }.count
    }
}

/// Date parsing/formatting for the API's "yyyy-MM-dd HH:mm:ss" created_at.
enum FinanceFmt {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: raw)
    }

    /// "yyyy-MM-dd HH:mm:ss" → "15 Jul 2026" (falls back to the raw string).
    static func date(_ raw: String?) -> String {
        guard let d = parse(raw) else { return (raw?.isEmpty == false) ? raw! : "—" }
        return fmt(d, "dd MMM yyyy")
    }

    /// "yyyy-MM-dd HH:mm:ss" → "15 Jul 2026, 13:58".
    static func dateTime(_ raw: String?) -> String {
        guard let d = parse(raw) else { return (raw?.isEmpty == false) ? raw! : "—" }
        return fmt(d, "dd MMM yyyy, HH:mm")
    }

    /// Format a Date directly (for the picked range labels).
    static func display(_ d: Date) -> String { fmt(d, "dd MMM yyyy") }

    private static func fmt(_ d: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: d)
    }
}
