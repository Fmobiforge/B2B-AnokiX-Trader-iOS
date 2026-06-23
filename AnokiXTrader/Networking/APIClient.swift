import Foundation

/// Errors surfaced to the UI from the API layer.
enum APIError: LocalizedError {
    case network
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .network:           return "Network error. Please try again."
        case .server(let msg):   return msg
        case .decoding:          return "Unexpected response from server."
        }
    }
}

/// Standard envelope returned by every AX endpoint: { status, message, data }.
struct APIEnvelope<T: Decodable>: Decodable {
    let status: Bool
    let message: String?
    let data: T?
}

/// Lightweight envelope for endpoints whose `data` shape we ignore (cart mutations
/// return `data: []`). Only the status/message matter.
struct StatusEnvelope: Decodable {
    let status: Bool
    let message: String?
}

/// A file part for a multipart upload.
struct MultipartFile {
    let field: String
    let fileName: String
    let mimeType: String
    let data: Data
}

/// Thin async wrapper over URLSession that mirrors the Android `ApiClient` /
/// `Http`. Same base URL and endpoint paths; Bearer token attached when present.
final class APIClient {
    static let shared = APIClient()

    /// Matches the Android `ApiClient.BASE_URL`.
    let baseURL = "http://155.117.20.51/ax/"

    /// Set after a successful login; nil before.
    var token: String?

    private let session = URLSession.shared

    private init() {}

    // MARK: - Endpoints

    func login(email: String, password: String) async throws -> LoginData {
        let form = ["email": email, "password": password, "portal_type": "trader"]
        return try await postForm("api/common/login", form: form, as: LoginData.self)
    }

    func getReference() async throws -> ReferenceData {
        try await get("api/common/reference", query: [:], as: ReferenceData.self)
    }

    /// Trader home dashboard. The backend endpoint isn't built yet (the Android
    /// `DashboardFragment` is mock-first too); wired here so iOS is ready when it ships.
    func getDashboard() async throws -> DashboardData {
        try await get("api/trader/dashboard", query: [:], as: DashboardData.self)
    }

    func getMarketplace(distributorId: String?) async throws -> MarketplaceData {
        var q: [String: String] = [:]
        if let id = distributorId, !id.isEmpty { q["distributor_id"] = id }
        return try await get("api/trader/marketplace", query: q, as: MarketplaceData.self)
    }

    func getProductDetail(id: String) async throws -> ProductDTO {
        let wrapper = try await get("api/common/product-detail",
                                    query: ["id": id], as: CommonProductData.self)
        guard let p = wrapper.product else { throw APIError.decoding }
        return p
    }

    /// Current cart status (lines + items_count / total_quantity / subtotal).
    func getCart() async throws -> CartData {
        try await get("api/trader/cart", query: [:], as: CartData.self)
    }

    func addToCart(productId: String, quantity: Int, unitPrice: Double,
                   barcode: String?, sku: String?) async throws {
        let form: [String: String] = [
            "product_id": productId,
            "quantity": String(quantity),
            "unit_price": String(format: "%.2f", unitPrice),
            "barcode": barcode ?? "",
            "sku": sku ?? ""
        ]
        try await postFormStatus("api/trader/cart/add", form: form)
    }

    func updateCartItem(cartItemId: String, quantity: Int, unitPrice: Double) async throws {
        let form: [String: String] = [
            "cart_item_id": cartItemId,
            "quantity": String(quantity),
            "unit_price": String(format: "%.2f", unitPrice)
        ]
        try await postFormStatus("api/trader/cart/update", form: form)
    }

    func deleteCartItem(cartItemId: String) async throws {
        try await postFormStatus("api/trader/cart/delete", form: ["cart_item_id": cartItemId])
    }

    /// Public trader self-registration (multipart). No token required.
    func registerTrader(fields: [String: String], files: [MultipartFile]) async throws {
        try await postMultipartStatus("api/trader/register", fields: fields, files: files)
    }

    func addressAutocomplete(_ keyword: String) async throws -> [AddressSuggestion] {
        let q = ["keyword": keyword, "str_countries": "country:ZA", "search_type": "address"]
        let data = try await get("api/common/google-auto-complete", query: q, as: AutocompleteData.self)
        return data.predictions ?? []
    }

    func coordinate(placeId: String) async throws -> CoordinateData {
        try await get("api/common/get-coordinate-from-placeid",
                      query: ["place_id": placeId], as: CoordinateData.self)
    }

    // MARK: - Core requests

    private func get<T: Decodable>(_ path: String, query: [String: String],
                                   as type: T.Type) async throws -> T {
        var comps = URLComponents(string: baseURL + path)
        if !query.isEmpty {
            comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps?.url else { throw APIError.network }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await send(req, as: type)
    }

    private func postForm<T: Decodable>(_ path: String, form: [String: String],
                                        as type: T.Type) async throws -> T {
        let req = formRequest(path, form: form)
        return try await send(req, as: type)
    }

    private func postFormStatus(_ path: String, form: [String: String]) async throws {
        let req = formRequest(path, form: form)
        try await sendStatus(req)
    }

    private func formRequest(_ path: String, form: [String: String]) -> URLRequest {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = form.map { key, value in
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? key
            return "\(k)=\(v)"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        return req
    }

    private func postMultipartStatus(_ path: String, fields: [String: String],
                                     files: [MultipartFile]) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let crlf = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)")
            body.append("\(value)\(crlf)")
        }
        for file in files {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.fileName)\"\(crlf)")
            body.append("Content-Type: \(file.mimeType)\(crlf)\(crlf)")
            body.append(file.data)
            body.append(crlf)
        }
        body.append("--\(boundary)--\(crlf)")
        req.httpBody = body
        try await sendStatus(req)
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        var req = request
        attachHeaders(&req)
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await session.data(for: req)
        } catch {
            throw APIError.network
        }
        do {
            let env = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
            if env.status, let payload = env.data {
                return payload
            }
            throw APIError.server(env.message ?? "Request failed")
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.decoding
        }
    }

    private func sendStatus(_ request: URLRequest) async throws {
        var req = request
        attachHeaders(&req)
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await session.data(for: req)
        } catch {
            throw APIError.network
        }
        if let env = try? JSONDecoder().decode(StatusEnvelope.self, from: data), env.status {
            return
        }
        let msg = (try? JSONDecoder().decode(StatusEnvelope.self, from: data))?.message
        throw APIError.server(msg ?? "Request failed")
    }

    private func attachHeaders(_ req: inout URLRequest) {
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}

private extension CharacterSet {
    /// application/x-www-form-urlencoded value encoding.
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._*")
        return cs
    }()
}
