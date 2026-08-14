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

    /// Report files come from a separate download service on its own port, which
    /// authenticates with the token in the JSON body rather than a Bearer header.
    /// Same host, so the existing ATS exception in Info.plist already covers it.
    let reportDownloadURL = "http://155.117.20.51:5721/api/report-download"

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

    /// Dedicated session for multipart uploads (Create Account KYC docs + logo).
    ///
    /// Uploads to this backend are slow (~40s per MB measured against the live server).
    /// `timeoutIntervalForRequest` is an *idle* timer that only resets when data is
    /// **received** — during a long upload nothing comes back, so a slow-but-progressing
    /// upload trips -1001 "request timed out" on the default 60s session even while it is
    /// still sending. We give uploads a very generous idle window (300s) and a 10-minute
    /// resource cap so the body has time to finish (parity with the Distributor app's
    /// `Http.multipartSession`).
    // `Alamofire.Session` (qualified — the app also has its own `Session` auth type).
    private let uploadSession: Alamofire.Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        return Alamofire.Session(configuration: config)
    }()

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

    /// Request a password-reset link (api/common/forgot-password). No token; sends the
    /// typed email + portal_type "trader". Only status/message matter.
    func forgotPassword(email: String) async throws {
        try await postFormStatus("api/common/forgot-password",
                                 form: ["email": email, "portal_type": "trader"])
    }

    func getReference() async throws -> ReferenceData {
        let data = try await get("api/common/reference", query: [:])
        return try decode(data)
    }

    /// Trader home dashboard: today's sales, anokiX wallet, anokiX rewards,
    /// pending orders, promotions, recent orders and top selling products.
    func getDashboard() async throws -> DashboardData {
        let data = try await get("api/trader/dashboard", query: [:])
        return try decode(data)
    }

    /// Live wallet balance. The `data` block is the wallet object itself — the same
    /// shape as the dashboard's `wallet` node — so it reuses `DashWalletDTO`.
    func getWallet() async throws -> DashWalletDTO {
        let data = try await get("api/common/wallet", query: [:])
        return try decode(data)
    }

    func getMarketplace(distributorId: String?) async throws -> MarketplaceData {
        var q: [String: String] = [:]
        if let id = distributorId, !id.isEmpty { q["distributor_id"] = id }
        let data = try await get("api/trader/marketplace", query: q)
        return try decode(data)
    }

    /// Category browse/filter page (api/trader/marketplace/category). All args except
    /// `categoryId` are optional; empty/false values are omitted so the backend applies
    /// no constraint — parity with the Android `ApiClient.getCategoryPage`.
    func getCategoryProducts(categoryId: String,
                             distributorId: String? = nil,
                             brands: String? = nil,
                             subCategories: String? = nil,
                             packSizes: String? = nil,
                             minPrice: String? = nil,
                             maxPrice: String? = nil,
                             onPromotion: Bool = false,
                             inStock: Bool = false,
                             search: String? = nil,
                             sortBy: String = "popularity",
                             page: Int = 1,
                             perPage: Int = 60) async throws -> CategoryPageData {
        var q: [String: String] = [
            "category_id": categoryId,
            "sort_by": sortBy.isEmpty ? "popularity" : sortBy,
            "page": String(page),
            "per_page": String(perPage)
        ]
        if let v = distributorId, !v.isEmpty { q["distributor_id"] = v }
        if let v = brands, !v.isEmpty { q["brands"] = v }
        if let v = subCategories, !v.isEmpty { q["sub_categories"] = v }
        if let v = packSizes, !v.isEmpty { q["pack_sizes"] = v }
        if let v = minPrice, !v.isEmpty { q["min_price"] = v }
        if let v = maxPrice, !v.isEmpty { q["max_price"] = v }
        if onPromotion { q["on_promotion"] = "1" }
        if inStock { q["in_stock"] = "1" }
        if let v = search, !v.trimmingCharacters(in: .whitespaces).isEmpty {
            q["search"] = v.trimmingCharacters(in: .whitespaces)
        }
        let data = try await get("api/trader/marketplace/category", query: q)
        return try decode(data)
    }

    /// Titled, paginated product collection (api/trader/marketplace/collection),
    /// e.g. type=recommended / best_sellers — opened from a Marketplace "View All".
    func getCollection(type: String, page: Int, perPage: Int) async throws -> CollectionData {
        let q: [String: String] = ["type": type, "page": String(page), "per_page": String(perPage)]
        let data = try await get("api/trader/marketplace/collection", query: q)
        return try decode(data)
    }

    /// Titled, paginated "Current Promotions" list (api/trader/marketplace/promotions),
    /// opened from the Marketplace "Current Promotions" View All.
    func getPromotions(page: Int, perPage: Int) async throws -> PromotionCollectionData {
        let q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        let data = try await get("api/trader/marketplace/promotions", query: q)
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

    /// Place an order from the selected cart lines (api/trader/orders/create).
    /// `cartItemIds` is sent as a JSON array string (e.g. `[10,11]`); times are
    /// `HH:mm:ss`. Only the envelope status/message decide success.
    func createOrder(distributorId: String?, cartItemIds: [String], deliveryDate: String,
                     startTime: String, endTime: String, notes: String,
                     deliveryAddress: String, paymentMethod: String) async throws {
        let form: [String: String] = [
            "distributor_id": distributorId ?? "",
            "cart_item_ids": "[" + cartItemIds.joined(separator: ",") + "]",
            "delivery_date": deliveryDate,
            "delivery_start_time": startTime,
            "delivery_end_time": endTime,
            "notes": notes,
            "delivery_address": deliveryAddress,
            "payment_method": paymentMethod
        ]
        try await postFormStatus("api/trader/orders/create", form: form)
    }

    /// List the trader's orders (api/trader/orders). All filters optional; a
    /// {@code status} of "all" is omitted so the server returns every status.
    func getOrders(distributorId: String?, search: String, dateFrom: String, dateTo: String,
                   status: String, page: Int, perPage: Int) async throws -> OrdersData {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if let id = distributorId, !id.isEmpty { q["distributor_id"] = id }
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { q["search"] = trimmed }
        if !dateFrom.isEmpty { q["date_from"] = dateFrom }
        if !dateTo.isEmpty { q["date_to"] = dateTo }
        if !status.isEmpty, status != "all" { q["status"] = status }
        let data = try await get("api/trader/orders", query: q)
        return try decode(data)
    }

    /// Full detail for one order (api/trader/orders?id=) — includes items[].
    func getOrder(id: String) async throws -> OrderDTO {
        let data = try await get("api/trader/orders", query: ["id": id])
        let wrapper: OrderDetailData = try decode(data)
        guard let order = wrapper.order else { throw APIError.decoding }
        return order
    }

    /// Purchase-order PDF (api/trader/orders/{id}/pdf) — { filename, mime, base64 data }.
    func getOrderPdf(id: String) async throws -> GrvPdfData {
        let data = try await get("api/trader/orders/\(id)/pdf", query: [:])
        return try decode(data)
    }

    // MARK: Goods Received (GRV)

    /// List the trader's Goods Received Vouchers + KPI summary (api/trader/grvs).
    func getGrvs() async throws -> GrvListData {
        let data = try await get("api/trader/grvs", query: [:])
        return try decode(data)
    }

    /// Single GRV with line items (api/trader/grvs/{id}).
    func getGrv(id: String) async throws -> GrvDTO {
        let data = try await get("api/trader/grvs/\(id)", query: [:])
        let wrapper: GrvDetailData = try decode(data)
        return wrapper.grv
    }

    /// Confirm receipt of a GRV (api/trader/grvs/{id}/confirm). `items` is a list of
    /// `["grv_item_id": .., "received_quantity": .., "damaged_quantity": ..]`; the
    /// accepted quantity is added to inventory server-side. Returns the updated GRV.
    @discardableResult
    func confirmGrv(id: String, items: [[String: Int]], note: String) async throws -> GrvDTO {
        let payload: [String: Any] = ["items": items, "note": note]
        let data = try await postJSON("api/trader/grvs/\(id)/confirm", json: payload)
        let wrapper: GrvDetailData = try decode(data)
        return wrapper.grv
    }

    /// Generated GRV PDF (api/trader/grvs/{id}/pdf) — { filename, mime, base64 data }.
    func getGrvPdf(id: String) async throws -> GrvPdfData {
        let data = try await get("api/trader/grvs/\(id)/pdf", query: [:])
        return try decode(data)
    }

    // MARK: Invoices

    /// List the trader's invoices (api/trader/invoices).
    func getInvoices() async throws -> InvoiceListData {
        let data = try await get("api/trader/invoices", query: [:])
        return try decode(data)
    }

    /// Generated invoice PDF (api/trader/invoices/{id}/pdf) — { filename, mime, base64 data }.
    func getInvoicePdf(id: String) async throws -> InvoicePdfData {
        let data = try await get("api/trader/invoices/\(id)/pdf", query: [:])
        return try decode(data)
    }

    // MARK: Finances

    /// The trader's anokiX wallet ledger + KPI summary (api/trader/finances).
    func getFinances() async throws -> FinancesData {
        let data = try await get("api/trader/finances", query: [:])
        return try decode(data)
    }

    // MARK: Distributors

    /// List the distributors the trader is partnered with (api/trader/distributors).
    func getDistributors() async throws -> DistributorsListData {
        let data = try await get("api/trader/distributors", query: [:])
        return try decode(data)
    }

    /// Request a change of distributor (api/trader/distributor/change-request).
    /// Sends `current_distributor_id` + optional `reason`; only status/message matter.
    func requestDistributorChange(currentDistributorId: String, reason: String) async throws {
        let form = ["current_distributor_id": currentDistributorId, "reason": reason]
        try await postFormStatus("api/trader/distributor/change-request", form: form)
    }

    // MARK: Inventory

    /// Live inventory dashboard (api/trader/inventory).
    func getInventory() async throws -> InventoryData {
        let data = try await get("api/trader/inventory", query: [:])
        return try decode(data)
    }

    /// Adjust a product's stock (api/trader/inventory/adjust). `quantity` is signed
    /// (positive adds, negative reduces).
    func adjustInventory(productId: Int, quantity: Int, reason: String) async throws {
        let payload: [String: Any] = ["product_id": productId, "quantity": quantity, "reason": reason]
        _ = try await postJSON("api/trader/inventory/adjust", json: payload)
    }

    /// One product's snapshot + movement ledger (api/trader/inventory/history).
    func getInventoryHistory(productId: Int) async throws -> InventoryHistoryData {
        let data = try await get("api/trader/inventory/history", query: ["product_id": String(productId)])
        return try decode(data)
    }

    /// Inventory analytics (api/trader/inventory/analytics): ageing, gross profit, reorder.
    func getInventoryAnalytics(days: Int) async throws -> InventoryAnalyticsData {
        let data = try await get("api/trader/inventory/analytics", query: ["days": String(days)])
        return try decode(data)
    }

    // MARK: Goods Returns (GRN)

    /// List the trader's Goods Returns + KPI summary (api/trader/returns).
    func getReturns() async throws -> ReturnsListData {
        let data = try await get("api/trader/returns", query: [:])
        return try decode(data)
    }

    /// File a goods return (api/trader/returns). `items` is a list of
    /// `["product_id": Int, "quantity": Int, "reason": String]`. Reduces stock
    /// immediately; the distributor reviews and may issue a credit note.
    func createReturn(items: [[String: Any]], reason: String, note: String, sourceGrvId: String?) async throws {
        var payload: [String: Any] = ["items": items, "reason": reason, "note": note]
        if let sourceGrvId, !sourceGrvId.isEmpty { payload["source_grv_id"] = sourceGrvId }
        _ = try await postJSON("api/trader/returns", json: payload)
    }

    // MARK: POS (Pagamio)

    /// Sellable POS products (api/trader/pos/products).
    func getPosProducts() async throws -> [PosProductDTO] {
        let data = try await get("api/trader/pos/products", query: [:])
        let raw = try data["products"].rawData()
        return (try? JSONDecoder().decode([PosProductDTO].self, from: raw)) ?? []
    }

    /// Complete a POS sale (api/trader/pos/sale, JSON). `items` is a list of
    /// `["product_id": Int, "quantity": Int, "unit_price": Double]`; `paymentMethod`
    /// is one of cash|wallet|card|qr|other. Returns the receipt.
    @discardableResult
    func createPosSale(items: [[String: Any]], paymentMethod: String, discount: Double) async throws -> PosSaleDTO {
        let payload: [String: Any] = [
            "items": items,
            "payment_method": paymentMethod,
            "discount": discount
        ]
        let data = try await postJSON("api/trader/pos/sale", json: payload)
        let wrapper: PosSaleData = try decode(data)
        return wrapper.sale
    }

    /// POS sales history + summary (api/trader/pos/sales). Filters optional.
    func getPosSales(dateFrom: String, dateTo: String, page: Int, perPage: Int) async throws -> PosSalesData {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if !dateFrom.isEmpty { q["date_from"] = dateFrom }
        if !dateTo.isEmpty { q["date_to"] = dateTo }
        let data = try await get("api/trader/pos/sales", query: q)
        return try decode(data)
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

    // MARK: Notifications (common)

    /// Live unread-notification count (api/common/notifications/unread-count).
    func getUnreadCount() async throws -> UnreadCountData {
        let data = try await get("api/common/notifications/unread-count", query: [:])
        return try decode(data)
    }

    /// Notification feed (api/common/notifications). `filter` is "all" (omitted) or
    /// "unread"; paged by `page`/`perPage`.
    func getNotifications(filter: String, page: Int, perPage: Int) async throws -> NotificationsListData {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if !filter.isEmpty, filter != "all" { q["filter"] = filter }
        let data = try await get("api/common/notifications", query: q)
        return try decode(data)
    }

    /// Mark one notification read (api/common/notifications/read, id=).
    func markNotificationRead(id: String) async throws {
        try await postFormStatus("api/common/notifications/read", form: ["id": id])
    }

    /// Mark every notification read (api/common/notifications/read, all=true).
    func markAllNotificationsRead() async throws {
        try await postFormStatus("api/common/notifications/read", form: ["all": "true"])
    }

    // MARK: Push / device tokens (FCM)

    /// Register this device's FCM token with the backend so the server can target it
    /// with pushes (api/common/device-tokens). Best-effort: only status/message matter.
    /// `platform` is "ios"; `deviceId` is the identifierForVendor.
    func registerDeviceToken(_ token: String, deviceId: String) async throws {
        // Field is `device_token` (not `token` — that key is reserved by the API gateway).
        try await postFormStatus("api/common/device-tokens",
                                 form: ["device_token": token, "platform": "ios"])
    }

    /// Remove this device's FCM token on logout (api/common/device-tokens/delete).
    func unregisterDeviceToken(_ token: String) async throws {
        try await postFormStatus("api/common/device-tokens/delete", form: ["device_token": token])
    }

    // MARK: Settings (account / preferences / security)

    /// Signed-in user for the Profile section (api/common/base-info → data.user).
    func getProfileUser() async throws -> ProfileUser {
        let data = try await get("api/common/base-info", query: [:])
        return ProfileUser(json: data["user"])
    }

    /// Timezone option list for the Preferences screen (api/common/base-info → data.timezones).
    func getTimezones() async throws -> [TimezoneOption] {
        let data = try await get("api/common/base-info", query: [:])
        return (data["timezones"].array ?? []).map(TimezoneOption.init(json:))
    }

    /// Display + format preferences incl. notification toggles (api/common/preferences).
    func getPreferences() async throws -> PreferencesDTO {
        let data = try await get("api/common/preferences", query: [:])
        return PreferencesDTO(json: data["preferences"])
    }

    /// Business profile incl. documents (api/trader/business/profile).
    func getBusinessProfile() async throws -> BusinessProfileDTO {
        let data = try await get("api/trader/business/profile", query: [:])
        return BusinessProfileDTO(json: data["profile"])
    }

    /// Update the trader's business profile (api/trader/business/profile/update) —
    /// partial multipart: only the supplied fields/files change (per-step Save in the
    /// Business editor). Authenticated; mirrors the Android `updateBusinessProfile`.
    func updateBusinessProfile(fields: [String: String], files: [MultipartFile]) async throws {
        try await uploadStatus("api/trader/business/profile/update", fields: fields, files: files)
    }

    /// Update the user's personal profile (api/common/profile/update).
    func updateProfile(firstName: String, lastName: String, email: String, phone: String) async throws {
        let payload: [String: Any] = [
            "first_name": firstName, "last_name": lastName,
            "email": email, "phone_number": phone,
        ]
        _ = try await postJSON("api/common/profile/update", json: payload)
    }

    /// Save the regional preferences only (api/common/preferences/update) — Preferences screen.
    func updatePreferenceValues(language: String, currency: String, timezone: String,
                                dateFormat: String, vasPaymentMode: String) async throws {
        let payload: [String: Any] = [
            "language": language, "currency": currency,
            "timezone": timezone, "date_format": dateFormat,
            "vas_payment_mode": vasPaymentMode,
        ]
        _ = try await postJSON("api/common/preferences/update", json: payload)
    }

    /// Save the notification toggles only (api/common/preferences/update) — Notifications screen.
    func updateNotifications(_ notifications: [String: Bool]) async throws {
        _ = try await postJSON("api/common/preferences/update", json: ["notifications": notifications])
    }

    /// Change the account password (api/common/profile/password).
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let payload: [String: Any] = ["current_password": currentPassword, "new_password": newPassword]
        _ = try await postJSON("api/common/profile/password", json: payload)
    }

    // MARK: Airtime & VAS (Limes, common — api/common/vas/*)

    /// VAS dashboard: recent transactions + KPI summary (api/common/vas/transactions).
    func getVasTransactions(page: Int, perPage: Int) async throws -> VasTransactionsData {
        let q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        let data = try await get("api/common/vas/transactions", query: q)
        return VasTransactionsData(json: data)
    }

    /// The Limes VAS category tree (api/common/vas/categories). Flatten via `.leaves`.
    func getVasCategories() async throws -> VasCategoriesData {
        let data = try await get("api/common/vas/categories", query: [:])
        return VasCategoriesData(json: data)
    }

    /// Purchasable products for one leaf category (api/common/vas/products).
    func getVasProducts(category: String, page: Int, limit: Int) async throws -> VasProductsData {
        let q: [String: String] = ["category": category, "page": String(page), "limit": String(limit)]
        let data = try await get("api/common/vas/products", query: q)
        return VasProductsData(json: data)
    }

    /// Buy a VAS product (api/common/vas/purchase, formdata). Paid from the anokiX
    /// wallet; the server debits and forwards to Limes. Only status/message decide
    /// success — the failure path carries the network's reason (e.g. inactive subscriber).
    func purchaseVas(productId: String, msisdn: String, amount: Double, sku: String,
                     name: String, category: String) async throws {
        let form: [String: String] = [
            "product_id": productId,
            "msisdn": msisdn,
            "amount": String(amount),
            "sku": sku,
            "name": name,
            "category": category,
            // Postman collection sends earn_commission=1 so the trader accrues VAS commission.
            "earn_commission": "1"
        ]
        try await postFormStatus("api/common/vas/purchase", form: form)
    }

    // MARK: - Reports

    /// Dashboard: the catalogue of report types, the reports already generated and the
    /// KPI summary — GET api/trader/reports.
    func getReports() async throws -> ReportsData {
        let data = try await get("api/trader/reports", query: [:])
        return try decode(data)
    }

    /// Build a report for a period. `reportKey` comes from `ReportAvailableDTO.key`;
    /// both dates are "yyyy-MM-dd". The envelope's message ("Till Sales ready — 2 rows.")
    /// is worth showing, so it comes back alongside the data.
    func generateReport(reportKey: String, from: String, to: String)
        async throws -> (data: ReportMutationData, message: String?) {
        let (node, message) = try await postFormWithMessage(
            "api/trader/reports/generate",
            form: ["report_key": reportKey, "from": from, "to": to])
        let result: ReportMutationData = try decode(node)
        return (result, message)
    }

    /// Delete a generated report; the response carries the refreshed summary.
    func deleteReport(id: Int) async throws -> (data: ReportMutationData, message: String?) {
        let (node, message) = try await postFormWithMessage(
            "api/trader/reports/delete", form: ["id": String(id)])
        let result: ReportMutationData = try decode(node)
        return (result, message)
    }

    /// Fetch the report file itself. On failure the download service answers with the
    /// usual JSON envelope instead of a file, so a JSON content type is treated as an
    /// error and its `message` surfaced.
    func downloadReport(id: Int) async throws -> ReportDownload {
        var request = URLRequest(url: URL(string: reportDownloadURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["id": id, "token": token ?? ""])

        let bytes: Data
        let response: URLResponse
        do {
            (bytes, response) = try await Self.downloadSession.data(for: request)
        } catch {
            throw APIError.network
        }

        let http = response as? HTTPURLResponse
        let contentType = (http?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        let status = http?.statusCode ?? 0

        guard (200..<300).contains(status), !bytes.isEmpty, !contentType.contains("json") else {
            // An envelope came back rather than a file — surface the server's wording.
            if let json = try? JSON(data: bytes), let message = json["message"].string,
               !message.isEmpty {
                throw APIError.server(message)
            }
            throw APIError.server("Could not download the report.")
        }

        return ReportDownload(
            bytes: bytes,
            contentType: contentType.isEmpty ? nil : contentType,
            fileName: Self.fileName(from: http?.value(forHTTPHeaderField: "Content-Disposition")))
    }

    /// Plain `URLSession` for the download: Alamofire's string serialisation would
    /// mangle a binary body, and file transfers want a longer resource timeout.
    private static let downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    /// Pull `filename="…"` out of a Content-Disposition header.
    private static func fileName(from disposition: String?) -> String? {
        guard let disposition else { return nil }
        let pattern = "filename\\*?=\"?(?:UTF-8'')?([^\";]+)\"?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: disposition, range: NSRange(disposition.startIndex..., in: disposition)),
              let range = Range(match.range(at: 1), in: disposition) else { return nil }
        // Strip any path the header might carry.
        let raw = String(disposition[range]).trimmingCharacters(in: .whitespaces)
        return raw.split(separator: "/").last.map(String.init)
    }

    // MARK: - Support Centre

    /// Landing screen: enabled channels, help-article taxonomy and the trader's tickets.
    func getSupportOverview() async throws -> SupportOverviewData {
        let data = try await get("api/common/support/overview", query: [:])
        return try decode(data)
    }

    /// Free-text help-article search.
    func searchSupportArticles(query: String) async throws -> SupportArticlesData {
        let data = try await get("api/common/support/articles/search", query: ["q": query])
        return try decode(data)
    }

    /// Open a ticket. `channel` is "web" (a written request, with a priority) or
    /// "callback" (a ring-me-back request, with a phone number); pass nil for the field
    /// that does not apply to the chosen channel.
    func createSupportTicket(subject: String, message: String, channel: String,
                             priority: String? = nil, callbackPhone: String? = nil,
                             category: String? = nil) async throws -> SupportTicketData {
        var form = ["subject": subject, "message": message, "channel": channel]
        if let priority, !priority.isEmpty { form["priority"] = priority }
        if let callbackPhone, !callbackPhone.isEmpty { form["callback_phone"] = callbackPhone }
        if let category, !category.isEmpty { form["category"] = category }
        let data = try await postForm("api/common/support/tickets", form: form)
        return try decode(data)
    }

    /// One ticket with its full message thread.
    func getSupportTicket(id: Int) async throws -> SupportTicketData {
        let data = try await get("api/common/support/tickets/\(id)", query: [:])
        return try decode(data)
    }

    /// Add a merchant reply; the response is the refreshed ticket.
    func replySupportTicket(ticketId: Int, message: String) async throws -> SupportTicketData {
        let data = try await postForm("api/common/support/tickets/reply",
                                      form: ["ticket_id": String(ticketId), "message": message])
        return try decode(data)
    }

    /// Close a ticket; the response is the refreshed ticket.
    func closeSupportTicket(ticketId: Int) async throws -> SupportTicketData {
        let data = try await postForm("api/common/support/tickets/close",
                                      form: ["ticket_id": String(ticketId)])
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

    /// POST form-urlencoded → the validated `data` node **and** the envelope's
    /// `message`, for endpoints whose wording is worth showing to the trader.
    private func postFormWithMessage(_ path: String, form: [String: String])
        async throws -> (JSON, String?) {
        let params: Parameters = form
        let request = AF.request(baseURL + path, method: .post, parameters: params,
                                 encoding: URLEncoding.httpBody, headers: authHeaders)
        let response = await request.serializingData().response
        switch response.result {
        case .success(let bytes):
            guard let json = try? JSON(data: bytes) else { throw APIError.decoding }
            if json["status"].boolValue { return (json["data"], json["message"].string) }
            throw APIError.server(json["message"].string ?? "Request failed")
        case .failure:
            throw APIError.network
        }
    }

    /// POST a JSON body → returns the validated `data` node as SwiftyJSON.
    private func postJSON(_ path: String, json: [String: Any]) async throws -> JSON {
        let request = AF.request(baseURL + path, method: .post, parameters: json,
                                 encoding: JSONEncoding.default, headers: authHeaders)
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
        // Use the dedicated long-idle-timeout session so slow KYC uploads don't trip -1001.
        let request = uploadSession.upload(multipartFormData: { form in
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
