import Foundation
import Alamofire
import SwiftyJSON

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

/// A file part for a multipart upload.
struct MultipartFile {
    let field: String
    let fileName: String
    let mimeType: String
    let data: Data
}

/// Thin async wrapper over **Alamofire** that mirrors the Android `ApiClient` /
/// `Http`. Same base URL and endpoint paths; Bearer token attached when present.
/// Token is persisted in UserDefaults (Android `SessionManager` / SharedPreferences).
final class APIClient {
    static let shared = APIClient()

    /// Matches the Android `ApiClient.BASE_URL`.
    let baseURL = "http://155.117.20.51/ax/"

    private static let tokenKey = "auth_token"

    /// Set after a successful login; restored on next launch.
    var token: String? {
        get { UserDefaults.standard.string(forKey: Self.tokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: Self.tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.tokenKey)
            }
        }
    }

    private init() {}

    private var authHeaders: HTTPHeaders {
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token, !token.isEmpty {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        return headers
    }

    // MARK: - Endpoints

    func login(email: String, password: String) async throws -> LoginData {
        let form = ["email": email, "password": password, "portal_type": "trader"]
        let data = try await postForm("api/common/login", form: form)
        return try decode(data)
    }

    func getReference() async throws -> ReferenceData {
        let data = try await get("api/common/reference", query: [:])
        return try decode(data)
    }

    /// Trader home dashboard. The backend endpoint isn't built yet (the Android
    /// `DashboardFragment` is mock-first too); wired here so iOS is ready when it ships.
    func getDashboard() async throws -> DashboardData {
        let data = try await get("api/trader/dashboard", query: [:])
        return try decode(data)
    }

    func getMarketplace(distributorId: String?) async throws -> MarketplaceData {
        var q: [String: String] = [:]
        if let id = distributorId, !id.isEmpty { q["distributor_id"] = id }
        let data = try await get("api/trader/marketplace", query: q)
        return try decode(data)
    }

    func getProductDetail(id: String) async throws -> ProductDTO {
        let data = try await get("api/common/product-detail", query: ["id": id])
        let wrapper: CommonProductData = try decode(data)
        guard let p = wrapper.product else { throw APIError.decoding }
        return p
    }

    /// Current cart status (lines + items_count / total_quantity / subtotal). Read
    /// with SwiftyJSON because this endpoint returns numeric ids/prices.
    func getCart() async throws -> CartData {
        let data = try await get("api/trader/cart", query: [:])
        return CartData(json: data)
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
        try await uploadStatus("api/trader/register", fields: fields, files: files)
    }

    func addressAutocomplete(_ keyword: String) async throws -> [AddressSuggestion] {
        let q = ["keyword": keyword, "str_countries": "country:ZA", "search_type": "address"]
        let data = try await get("api/common/google-auto-complete", query: q)
        let wrapper: AutocompleteData = try decode(data)
        return wrapper.predictions ?? []
    }

    func coordinate(placeId: String) async throws -> CoordinateData {
        let data = try await get("api/common/get-coordinate-from-placeid", query: ["place_id": placeId])
        return try decode(data)
    }

    // MARK: - Core requests (Alamofire)

    /// GET → returns the validated `data` node as SwiftyJSON.
    private func get(_ path: String, query: [String: String]) async throws -> JSON {
        let params: Parameters = query
        let request = AF.request(baseURL + path, method: .get, parameters: params,
                                 encoding: URLEncoding.queryString, headers: authHeaders)
        return try await dataNode(request)
    }

    /// POST form-urlencoded → returns the validated `data` node as SwiftyJSON.
    private func postForm(_ path: String, form: [String: String]) async throws -> JSON {
        let params: Parameters = form
        let request = AF.request(baseURL + path, method: .post, parameters: params,
                                 encoding: URLEncoding.httpBody, headers: authHeaders)
        return try await dataNode(request)
    }

    /// POST form where only `status`/`message` matter (cart mutations return `data: []`).
    private func postFormStatus(_ path: String, form: [String: String]) async throws {
        let params: Parameters = form
        let request = AF.request(baseURL + path, method: .post, parameters: params,
                                 encoding: URLEncoding.httpBody, headers: authHeaders)
        try await statusOnly(request)
    }

    /// Multipart upload where only `status`/`message` matter.
    private func uploadStatus(_ path: String, fields: [String: String],
                              files: [MultipartFile]) async throws {
        let request = AF.upload(multipartFormData: { form in
            for (key, value) in fields {
                form.append(Data(value.utf8), withName: key)
            }
            for file in files {
                form.append(file.data, withName: file.field,
                            fileName: file.fileName, mimeType: file.mimeType)
            }
        }, to: baseURL + path, method: .post, headers: authHeaders)
        try await statusOnly(request)
    }

    // MARK: - Response handling

    /// Awaits the response, validates the envelope `status`, returns the `data` node.
    private func dataNode(_ request: DataRequest) async throws -> JSON {
        let response = await request.serializingData().response
        switch response.result {
        case .success(let bytes):
            guard let json = try? JSON(data: bytes) else { throw APIError.decoding }
            if json["status"].boolValue { return json["data"] }
            throw APIError.server(json["message"].string ?? "Request failed")
        case .failure:
            throw APIError.network
        }
    }

    /// Awaits the response and validates the envelope `status` only.
    private func statusOnly(_ request: DataRequest) async throws {
        let response = await request.serializingData().response
        switch response.result {
        case .success(let bytes):
            guard let json = try? JSON(data: bytes) else { throw APIError.decoding }
            if json["status"].boolValue { return }
            throw APIError.server(json["message"].string ?? "Request failed")
        case .failure:
            throw APIError.network
        }
    }

    /// Decode a Codable DTO from a SwiftyJSON node.
    private func decode<T: Decodable>(_ json: JSON) throws -> T {
        do {
            let raw = try json.rawData()
            return try JSONDecoder().decode(T.self, from: raw)
        } catch {
            throw APIError.decoding
        }
    }
}
