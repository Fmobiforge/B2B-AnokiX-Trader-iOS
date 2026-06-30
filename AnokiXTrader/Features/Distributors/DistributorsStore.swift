import SwiftUI

// MARK: - Distributor DTOs (GET api/trader/distributors)

/// Envelope `data` for the trader's distributor list.
struct DistributorsListData: Decodable {
    let distributors: [TraderDistributorDTO]
}

/// One distributor the trader is partnered with. Named `TraderDistributorDTO` to
/// avoid clashing with the slimmer marketplace `DistributorDTO` in DTOs.swift.
/// `id` and `products_available` may arrive as numbers or strings, and
/// `minimum_order` may be null, so all are decoded leniently.
struct TraderDistributorDTO: Decodable, Identifiable, Hashable {
    let id: String
    let distributor_code: String?
    let company_legal_name: String?
    let trading_name: String?
    let display_name: String?
    let logo_url: String?
    let company_email: String?
    let company_phone_number: String?
    let contact_name: String?
    let contact_email: String?
    let contact_phone: String?
    let address: String?
    let status: String?
    let preferred_delivery_days: String?
    let products_available: Int
    let minimum_order: String?

    enum CodingKeys: String, CodingKey {
        case id, distributor_code, company_legal_name, trading_name, display_name, logo_url
        case company_email, company_phone_number, contact_name, contact_email, contact_phone
        case address, status, preferred_delivery_days, products_available, minimum_order
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = TraderDistributorDTO.flexString(c, .id) ?? ""
        distributor_code = try c.decodeIfPresent(String.self, forKey: .distributor_code)
        company_legal_name = try c.decodeIfPresent(String.self, forKey: .company_legal_name)
        trading_name = try c.decodeIfPresent(String.self, forKey: .trading_name)
        display_name = try c.decodeIfPresent(String.self, forKey: .display_name)
        logo_url = try c.decodeIfPresent(String.self, forKey: .logo_url)
        company_email = try c.decodeIfPresent(String.self, forKey: .company_email)
        company_phone_number = try c.decodeIfPresent(String.self, forKey: .company_phone_number)
        contact_name = try c.decodeIfPresent(String.self, forKey: .contact_name)
        contact_email = try c.decodeIfPresent(String.self, forKey: .contact_email)
        contact_phone = try c.decodeIfPresent(String.self, forKey: .contact_phone)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        preferred_delivery_days = try c.decodeIfPresent(String.self, forKey: .preferred_delivery_days)
        if let n = try? c.decode(Int.self, forKey: .products_available) {
            products_available = n
        } else if let s = TraderDistributorDTO.flexString(c, .products_available), let n = Int(s) {
            products_available = n
        } else {
            products_available = 0
        }
        minimum_order = TraderDistributorDTO.flexString(c, .minimum_order)
    }

    /// Decode a field that may be a JSON string or number into a String (nil if absent/null).
    private static func flexString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
        if let d = try? c.decode(Double.self, forKey: key) { return String(d) }
        return nil
    }

    /// Best human label — prefer the registered legal name, then backend display, then trading.
    var displayName: String {
        if let c = company_legal_name, !c.isEmpty { return c }
        if let d = display_name, !d.isEmpty { return d }
        if let t = trading_name, !t.isEmpty { return t }
        return distributor_code ?? "Distributor"
    }

    /// Single uppercase initial for the logo tile.
    var initial: String {
        let n = displayName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "D" : String(n.prefix(1)).uppercased()
    }

    var isActive: Bool {
        guard let s = status else { return true }
        return s.lowercased() == "active"
    }
}

// MARK: - Store

/// Loads the trader's distributors (GET api/trader/distributors) and submits
/// distributor change requests (POST api/trader/distributor/change-request).
@MainActor
final class DistributorsStore: ObservableObject {
    @Published var distributors: [TraderDistributorDTO] = []
    @Published var loading = false
    @Published var error: String?

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getDistributors()
            distributors = data.distributors
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load distributors."
            distributors = []
        }
        loading = false
    }

    /// Submit a change request for the given distributor. Throws on failure so the
    /// form can surface the message.
    func requestChange(currentDistributorId: String, reason: String) async throws {
        try await APIClient.shared.requestDistributorChange(
            currentDistributorId: currentDistributorId, reason: reason)
    }
}
