import SwiftUI

// MARK: - GRV DTOs (GET api/trader/grvs, /{id}, /{id}/confirm, /{id}/pdf)

/// Envelope `data` for the GRV list: vouchers + KPI summary.
struct GrvListData: Decodable {
    let grvs: [GrvDTO]
    let summary: GrvSummaryDTO?
}

/// Wraps a single GRV (returned by GET /{id} and POST /{id}/confirm).
struct GrvDetailData: Decodable {
    let grv: GrvDTO
}

/// GET /{id}/pdf — `data` is a base64-encoded PDF.
struct GrvPdfData: Decodable {
    let filename: String?
    let mime: String?
    let data: String?
}

struct GrvSummaryDTO: Decodable {
    let total_grvs: Int?
    let awaiting: Int?
    let received: Int?
    let line_items: Int?
}

/// One Goods Received Voucher. Created (status "pending") when an order is
/// delivered; stock is added only once the trader confirms receipt.
struct GrvDTO: Decodable, Identifiable, Hashable {
    let id: String
    let grv_number: String
    let order_number: String?
    let invoice_number: String?
    let distributor_name: String?
    let delivery_date: String?
    let status: String
    let items: [GrvItemDTO]?

    var isPending: Bool { status.lowercased() == "pending" }
    var lineItems: [GrvItemDTO] { items ?? [] }
    var lineCount: Int { lineItems.count }

    /// Display label + colour tone for the status badge.
    var statusLabel: String {
        switch status.lowercased() {
        case "received":           return "Received"
        case "partially_received": return "Partially Received"
        case "pending":            return "Awaiting Receipt"
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

/// One line on a GRV. Quantities are decoded leniently (default 0) so a missing
/// field never fails the whole response.
struct GrvItemDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let product_id: Int?
    let name: String?
    let sku: String?
    let ordered_quantity: Int?
    let received_quantity: Int?
    let damaged_quantity: Int?
    let unit_price: Double?

    var ordered: Int { ordered_quantity ?? 0 }
    var received: Int { received_quantity ?? 0 }
    var damaged: Int { damaged_quantity ?? 0 }
}

// MARK: - Store

/// Loads the trader's GRVs from GET api/trader/grvs and confirms receipts.
@MainActor
final class GoodsReceivedStore: ObservableObject {
    @Published var grvs: [GrvDTO] = []
    @Published var summary: GrvSummaryDTO?
    @Published var loading = false
    @Published var error: String?

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getGrvs()
            grvs = data.grvs
            summary = data.summary
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load goods received vouchers."
            grvs = []
            summary = nil
        }
        loading = false
    }

    /// Confirm receipt (full or partial), then refresh so the list + KPIs update.
    func confirm(id: String, items: [[String: Int]], note: String) async throws {
        _ = try await APIClient.shared.confirmGrv(id: id, items: items, note: note)
        await load()
    }

    // KPI accessors with a fallback computed from the list.
    var totalCount: Int { summary?.total_grvs ?? grvs.count }
    var awaitingCount: Int { summary?.awaiting ?? grvs.filter { $0.isPending }.count }
    var receivedCount: Int { summary?.received ?? grvs.filter { $0.status.lowercased() == "received" }.count }
    var lineItemCount: Int { summary?.line_items ?? grvs.reduce(0) { $0 + $1.lineCount } }
}

/// "yyyy-MM-dd" → "25 Jun 2026" (falls back to the raw string).
enum GrvFmt {
    static func deliveryDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: raw) else { return raw }
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: d)
    }
}
