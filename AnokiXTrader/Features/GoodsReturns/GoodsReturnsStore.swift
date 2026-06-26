import SwiftUI

// MARK: - GRN DTOs (GET api/trader/returns, POST api/trader/returns)

struct ReturnsListData: Decodable {
    let returns: [ReturnDTO]
    let summary: ReturnsSummaryDTO?
}

struct ReturnsSummaryDTO: Decodable {
    let total_returns: Int?
    let approved: Int?
    let pending: Int?
    let credit_issued: Double?
}

/// One Goods Return Note. A return reduces stock immediately; the distributor
/// reviews it and may issue a credit note (shown once approved).
struct ReturnDTO: Decodable, Identifiable, Hashable {
    let id: String
    let grn_number: String
    let distributor_name: String?
    let source_grv_id: String?
    let reason: String?
    let status: String
    let item_count: String?
    let total_quantity: String?
    let note: String?
    let decision_note: String?
    let created_at: String?
    let credit_note_number: String?
    let credit_note_total: Double?
    let items: [ReturnItemDTO]?

    var isApproved: Bool { status.lowercased() == "approved" }
    var lineItems: [ReturnItemDTO] { items ?? [] }
    var lineCount: Int { lineItems.count }
    var hasCreditNote: Bool { !(credit_note_number ?? "").isEmpty }

    var statusLabel: String {
        switch status.lowercased() {
        case "approved":  return "Approved"
        case "rejected":  return "Rejected"
        case "submitted": return "Submitted"
        default:          return status.isEmpty ? "—" : status
        }
    }

    var statusTone: (fg: Color, bg: Color) {
        switch status.lowercased() {
        case "approved":  return (Brand.success, Brand.successBg)
        case "rejected":  return (Brand.danger, Brand.dangerBg)
        case "submitted": return (Brand.warning, Brand.warningBg)
        default:          return (Brand.purple, Brand.purpleLight)
        }
    }
}

struct ReturnItemDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let product_id: Int?
    let name: String?
    let quantity: Int?
    let reason: String?

    var qty: Int { quantity ?? 0 }
}

// MARK: - Store

@MainActor
final class GoodsReturnsStore: ObservableObject {
    @Published var returns: [ReturnDTO] = []
    @Published var summary: ReturnsSummaryDTO?
    @Published var loading = false
    @Published var error: String?

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getReturns()
            returns = data.returns
            summary = data.summary
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load returns."
            returns = []
            summary = nil
        }
        loading = false
    }

    /// File a new return, then refresh so the list + KPIs update.
    func create(items: [[String: Any]], reason: String, note: String, sourceGrvId: String?) async throws {
        try await APIClient.shared.createReturn(items: items, reason: reason, note: note, sourceGrvId: sourceGrvId)
        await load()
    }

    var totalCount: Int { summary?.total_returns ?? returns.count }
    var approvedCount: Int { summary?.approved ?? returns.filter { $0.isApproved }.count }
    var pendingCount: Int { summary?.pending ?? returns.filter { !$0.isApproved }.count }
    var creditIssued: Double {
        summary?.credit_issued ?? returns.reduce(0) { $0 + ($1.credit_note_total ?? 0) }
    }
}

// MARK: - Reasons + formatting

/// Goods-return reasons shared by the GRN list + Return Goods form.
enum ReturnReasonOption {
    static let keys = ["damaged", "expired", "incorrect", "overstock", "recall", "other"]
    static let labels = ["Damaged stock", "Expired", "Incorrect item", "Overstock", "Recall", "Other"]

    static func label(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "" }
        if let i = keys.firstIndex(of: key.lowercased()) { return labels[i] }
        return key.prefix(1).uppercased() + key.dropFirst()
    }
}

enum GrnFmt {
    /// "R1,234.50" with grouped thousands.
    static func money(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return "R" + (f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
    }

    /// "dd/MM/yyyy HH:mm:ss" → "25 Jun 2026" (falls back to the raw string).
    static func date(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy HH:mm:ss"
        guard let d = f.date(from: raw) else { return raw }
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: d)
    }
}
