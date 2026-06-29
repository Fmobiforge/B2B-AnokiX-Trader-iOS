import SwiftUI

// MARK: - Invoice DTOs (GET api/trader/invoices, /{id}/pdf)

/// Envelope `data` for the invoice list. The API returns no KPI summary, so the
/// screen computes the cards (total / total value / average / this month) itself.
struct InvoiceListData: Decodable {
    let invoices: [InvoiceDTO]
}

/// GET /{id}/pdf — `data` is a base64-encoded PDF.
struct InvoicePdfData: Decodable {
    let filename: String?
    let mime: String?
    let data: String?
}

/// One invoice. Generated automatically when an order is delivered. Money fields
/// arrive as strings (e.g. "400.00"), so they're decoded leniently to Double.
struct InvoiceDTO: Decodable, Identifiable, Hashable {
    let id: String
    let invoice_number: String
    let order_number: String?
    let status: String
    let created_at: String?
    let subtotal: Double
    let total_amount: Double
    let items: [InvoiceItemDTO]?

    var lineItems: [InvoiceItemDTO] { items ?? [] }
    var lineCount: Int { lineItems.count }

    enum CodingKeys: String, CodingKey {
        case id, invoice_number, order_number, status, created_at
        case subtotal, total_amount, items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        invoice_number = try c.decode(String.self, forKey: .invoice_number)
        order_number = try c.decodeIfPresent(String.self, forKey: .order_number)
        status = try c.decode(String.self, forKey: .status)
        created_at = try c.decodeIfPresent(String.self, forKey: .created_at)
        subtotal = InvoiceDTO.flexDouble(c, .subtotal)
        total_amount = InvoiceDTO.flexDouble(c, .total_amount)
        items = try c.decodeIfPresent([InvoiceItemDTO].self, forKey: .items)
    }

    /// Decode a money field that may arrive as a JSON string or number.
    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }

    /// Display label + colour tone for the status badge.
    var statusLabel: String {
        switch status.lowercased() {
        case "received":           return "Received"
        case "partially_received": return "Partially Received"
        case "pending":            return "Pending"
        default:                   return status.isEmpty ? "—" : status
        }
    }

    var statusTone: (fg: Color, bg: Color) {
        switch status.lowercased() {
        case "received":           return (Brand.success, Brand.successBg)
        case "partially_received": return (Brand.info, Brand.infoBg)
        case "pending":            return (Brand.warning, Brand.warningBg)
        default:                   return (Brand.purple, Brand.purpleLight)
        }
    }
}

/// One line on an invoice. Quantities/money decoded leniently so a missing field
/// never fails the whole response.
struct InvoiceItemDTO: Decodable, Identifiable, Hashable {
    let product_id: Int?
    let name: String?
    let sku: String?
    let quantity: Int?
    let unit_price: Double?
    let line_total: Double?

    var id: String { "\(product_id ?? 0)-\(sku ?? "")" }
}

// MARK: - Store

/// Loads the trader's invoices from GET api/trader/invoices and computes the KPIs.
@MainActor
final class InvoicesStore: ObservableObject {
    @Published var invoices: [InvoiceDTO] = []
    @Published var loading = false
    @Published var error: String?

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getInvoices()
            invoices = data.invoices
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load invoices."
            invoices = []
        }
        loading = false
    }

    // KPI accessors computed from the list.
    var totalCount: Int { invoices.count }
    var totalValue: Double { invoices.reduce(0) { $0 + $1.total_amount } }
    var averageValue: Double { invoices.isEmpty ? 0 : totalValue / Double(invoices.count) }

    /// Count of invoices created in the current calendar month.
    var thisMonthCount: Int {
        let cal = Calendar.current
        let now = Date()
        return invoices.filter { inv in
            guard let d = InvoiceFmt.parse(inv.created_at) else { return false }
            return cal.component(.month, from: d) == cal.component(.month, from: now)
                && cal.component(.year, from: d) == cal.component(.year, from: now)
        }.count
    }
}

/// Date parsing/formatting for the API's "dd/MM/yyyy HH:mm:ss" created_at.
enum InvoiceFmt {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return f.date(from: raw)
    }

    /// "dd/MM/yyyy HH:mm:ss" → "25 Jun 2026" (falls back to the raw string).
    static func date(_ raw: String?) -> String {
        guard let d = parse(raw) else { return (raw?.isEmpty == false) ? raw! : "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: d)
    }
}
