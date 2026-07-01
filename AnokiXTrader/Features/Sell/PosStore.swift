import SwiftUI

// MARK: - POS DTOs (api/trader/pos/*)

/// A sellable POS product (GET api/trader/pos/products). Prices are VAT-inclusive
/// rands; `units` is on-hand stock. Property names match the JSON keys.
struct PosProductDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let sku: String?
    let barcode: String?
    let category: String?
    let categoryKey: String?
    let price: Double
    let units: Int
    let in_stock: Bool
    let image_url: String?

    var sellable: Bool { in_stock && units > 0 }
}

/// Completed sale receipt (POST api/trader/pos/sale).
struct PosSaleDTO: Decodable, Identifiable {
    let id: Int
    let sale_number: String?
    let subtotal: Double
    let discount: Double
    let tax_amount: Double
    let tax_rate: Double?
    let subtotal_excl_tax: Double
    let total_amount: Double
    let item_count: Int
    let payment_method: String?
    let items: [PosSaleItemDTO]?
}

struct PosSaleItemDTO: Decodable, Identifiable, Hashable {
    let product_id: Int
    let name: String?
    let quantity: Int
    let unit_price: Double
    let line_total: Double
    var id: Int { product_id }
}

struct PosSaleData: Decodable { let sale: PosSaleDTO }

/// Sales history + summary (GET api/trader/pos/sales).
struct PosSalesData: Decodable {
    let sales: [PosSaleRow]?
    let summary: PosSalesSummary?
    let pagination: PosPagination?
}

struct PosSaleRow: Decodable, Identifiable, Hashable {
    let id: Int
    let sale_number: String?
    let subtotal: Double
    let discount: Double
    let tax_amount: Double
    let total_amount: Double
    let item_count: Int
    let payment_method: String?
    let created_at: String?
}

struct PosSalesSummary: Decodable {
    let total_sales: Double
    let transactions: Int
    let average_sale: Double
    let items_sold: Int
}

struct PosPagination: Decodable {
    let page: Int
    let per_page: Int
    let total: Int
    let total_pages: Int
}

// MARK: - Payment methods

/// POS payment-method keys accepted by the API + their display labels.
enum PosPayment: String, CaseIterable, Identifiable {
    case cash, wallet, card, qr, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cash:   return "Cash"
        case .wallet: return "Wallet"
        case .card:   return "Card"
        case .qr:     return "QR"
        case .other:  return "Other"
        }
    }
    static func label(for key: String?) -> String {
        guard let key, let m = PosPayment(rawValue: key.lowercased()) else { return key ?? "" }
        return m.label
    }
}

// MARK: - Store

/// Loads sellable POS products. Mirrors the Android `SellFragment` live fetch.
@MainActor
final class PosStore: ObservableObject {
    @Published var products: [PosProductDTO] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            products = try await APIClient.shared.getPosProducts()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load products."
        }
        isLoading = false
    }

    /// Distinct product categories (for the filter chips), "All" first.
    var categories: [String] {
        var seen: [String] = ["All"]
        for p in products {
            if let c = p.category, !c.isEmpty, !seen.contains(c) { seen.append(c) }
        }
        return seen
    }
}

// MARK: - Sales screen (drawer › Sales)

/// Sales — review sales performance + receipts (`api/trader/pos/sales`). Date-range
/// filter defaults to Monday-this-week → today; KPI summary; receipts list with
/// payment-type badges; pagination. Hosted by `ModuleHost` (provides the nav bar).
struct SalesView: View {
    private static let perPage = 10

    @State private var fromDate: Date = SalesView.startOfWeek()
    @State private var toDate: Date = Date()
    @State private var showDatePicker = false
    @State private var sales: [PosSaleRow] = []
    @State private var summary: PosSalesSummary?
    @State private var page = 1
    @State private var totalPages = 1
    @State private var totalCount = 0
    @State private var isLoading = true

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private static let apiFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Review your sales performance and receipts.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Date range — tap to pick start + end together
                Button { showDatePicker = true } label: {
                    HStack(spacing: 10) {
                        Text(Self.dispFmt.string(from: fromDate))
                            .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                        Image(systemName: "arrow.right").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        Text(Self.dispFmt.string(from: toDate))
                            .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                        Spacer()
                        Image(systemName: "calendar").foregroundColor(Brand.textSecondary)
                    }
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(Brand.surfaceVariant)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // KPI summary
                LazyVGrid(columns: cols, spacing: 12) {
                    StatTile(label: "Total Sales", value: Money.rand(summary?.total_sales ?? 0),
                             valueColor: Brand.purple, icon: "dollarsign.circle.fill", iconTint: Brand.success)
                    StatTile(label: "Transactions", value: "\(summary?.transactions ?? 0)",
                             icon: "bag.fill", iconTint: Color(hex: "#2563EB"))
                    StatTile(label: "Average Sale", value: Money.rand(summary?.average_sale ?? 0),
                             icon: "chart.line.uptrend.xyaxis", iconTint: Color(hex: "#EA580C"))
                    StatTile(label: "Items Sold", value: "\(summary?.items_sold ?? 0)",
                             icon: "square.grid.2x2.fill", iconTint: Brand.purple)
                }

                // Receipts
                if isLoading {
                    ProgressView().padding(.top, 40)
                } else if sales.isEmpty {
                    Text("No sales in this period yet.")
                        .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(sales) { row in
                            saleRow(row)
                            if row.id != sales.last?.id { Divider() }
                        }
                    }
                    .card(padding: 0)

                    paginationBar
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { await load() }
        .sheet(isPresented: $showDatePicker) {
            DateRangeSheet(from: fromDate, to: toDate) { from, to in
                fromDate = from
                toDate = to
                reload()
            }
        }
    }

    private func saleRow(_ row: PosSaleRow) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.sale_number ?? "")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.purple)
                Text(Self.formatDateTime(row.created_at))
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.rand(row.total_amount))
                    .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                HStack(spacing: 8) {
                    Text(PosPayment.label(for: row.payment_method))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .foregroundColor(Self.paymentTint(row.payment_method))
                        .overlay(Capsule().stroke(Self.paymentTint(row.payment_method), lineWidth: 1))
                    Text("\(row.item_count) \(row.item_count == 1 ? "item" : "items")")
                        .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private var paginationBar: some View {
        HStack {
            Text(totalCount == 0 ? "Showing 0 sales"
                 : "Showing \((page - 1) * Self.perPage + 1)–\((page - 1) * Self.perPage + sales.count) of \(totalCount) sales")
                .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            Spacer()
            Button { if page > 1 { page -= 1; Task { await load() } } } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
                    .background(Brand.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(page <= 1).opacity(page <= 1 ? 0.4 : 1)
            Button { if page < totalPages { page += 1; Task { await load() } } } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
                    .background(Brand.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(page >= totalPages).opacity(page >= totalPages ? 0.4 : 1)
        }
        .foregroundColor(Brand.textPrimary)
    }

    private func reload() {
        page = 1
        Task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let data = try await APIClient.shared.getPosSales(
                dateFrom: Self.apiFmt.string(from: fromDate),
                dateTo: Self.apiFmt.string(from: toDate),
                page: page, perPage: Self.perPage)
            sales = data.sales ?? []
            summary = data.summary
            if let p = data.pagination {
                page = p.page
                totalPages = max(1, p.total_pages)
                totalCount = p.total
            } else {
                totalPages = 1; totalCount = sales.count
            }
        } catch {
            sales = []; totalCount = 0; totalPages = 1
        }
        isLoading = false
    }

    /// Monday 00:00 of the current week.
    private static func startOfWeek() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let now = Date()
        return cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    /// Date-range pill label, e.g. "22 Jun 2026".
    private static let dispFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd MMM yyyy"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static let inFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static let outFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd MMM yyyy · HH:mm"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    /// "26/06/2026 11:22:23" → "26 Jun 2026 · 11:22"; falls back to the raw value.
    static func formatDateTime(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        if let d = inFmt.date(from: raw) { return outFmt.string(from: d) }
        return raw
    }

    static func paymentTint(_ key: String?) -> Color {
        switch key?.lowercased() {
        case "cash":   return Brand.success
        case "wallet": return Color(hex: "#EA580C")
        default:       return Brand.purple
        }
    }
}

// MARK: - Sale Completed receipt (mirrors POS-After-Complete-Sale.png)

struct PosReceiptView: View {
    let sale: PosSaleDTO
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sale Completed").font(.system(size: 19, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Button(action: onDone) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.textSecondary)
                }
            }
            .padding(.bottom, 16)

            Text(sale.sale_number ?? "")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.purple)
                .padding(.bottom, 8)

            ForEach(sale.items ?? []) { item in
                row("\(item.quantity) × \(item.name ?? "")", Money.rand(item.line_total))
            }

            Divider().padding(.vertical, 10)

            if sale.discount > 0 {
                row("Discount", "-" + Money.rand(sale.discount))
            }
            row("Subtotal (excl. VAT)", Money.rand(sale.subtotal_excl_tax))
            row("VAT (15%)", Money.rand(sale.tax_amount))
            row("Total (\(PosPayment.label(for: sale.payment_method)))", Money.rand(sale.total_amount), emphasised: true)

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 18)
        }
        .padding(20)
    }

    private func row(_ label: String, _ value: String, emphasised: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: emphasised ? 16 : 14, weight: emphasised ? .bold : .regular))
                .foregroundColor(emphasised ? Brand.purple : Brand.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: emphasised ? 16 : 14, weight: emphasised ? .bold : .regular))
                .foregroundColor(emphasised ? Brand.purple : Brand.textPrimary)
        }
        .padding(.vertical, 3)
    }
}
