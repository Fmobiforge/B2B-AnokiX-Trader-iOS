import Foundation

// MARK: - Login

struct LoginData: Decodable {
    let token: String?
    let user: LoginUser?
}

struct LoginUser: Decodable {
    let first_name: String?
    let last_name: String?
    let email: String?
    let role_label: String?
}

// MARK: - Reference (categories / distributors / trader types)

struct ReferenceData: Decodable {
    let product_categories: [ProductCategoryDTO]?
    let distributors: [DistributorRefDTO]?
    let trader_types: [TraderTypeDTO]?
}

struct ProductCategoryDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let slug: String?
    let parent_id: Int?
}

struct DistributorRefDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let distributor_code: String?
    let company_legal_name: String?
    let trading_name: String?
    let company_email: String?
    let address: String?

    var displayName: String {
        if let t = trading_name, !t.isEmpty { return t }
        if let c = company_legal_name, !c.isEmpty { return c }
        return distributor_code ?? "Distributor"
    }
}

struct TraderTypeDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String?
    let icon: String?
    let sort_order: Int?
}

// MARK: - Marketplace

struct MarketplaceData: Decodable {
    let meta: MetaDTO?
    let selected_distributor: DistributorDTO?
    let banners: [BannerDTO]?
    let recommended: [ProductDTO]?
    let best_sellers: [ProductDTO]?
    let promotions: [PromotionDTO]?
    let business_insights: BusinessInsightsDTO?
    let my_distributors: [DistributorDTO]?

    var currencySymbol: String {
        if let s = meta?.currency?.symbol, !s.isEmpty { return s }
        return "R"
    }
}

struct MetaDTO: Decodable {
    let currency: CurrencyDTO?
}

struct CurrencyDTO: Decodable {
    let code: String?
    let symbol: String?
}

struct DistributorDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let distributor_code: String?
    let company_legal_name: String?
    let trading_name: String?
    let display_name: String?
    let address: String?

    var displayName: String {
        if let d = display_name, !d.isEmpty { return d }
        if let t = trading_name, !t.isEmpty { return t }
        if let c = company_legal_name, !c.isEmpty { return c }
        return distributor_code ?? "Distributor"
    }
}

struct MediaDTO: Decodable, Hashable {
    let media_type: String?
    let file_url: String?
}

struct BannerDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let campaign_type: String?
    let name: String?
    let description: String?
    let banner_file: MediaDTO?
    let video_file: MediaDTO?

    var mediaURL: String? {
        if let v = video_file?.file_url, !v.isEmpty { return v }
        return banner_file?.file_url
    }
    var isVideo: Bool { (video_file?.file_url?.isEmpty == false) }
}

struct PromotionDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let campaign_type: String?
    let name: String?
    let description: String?
    let banner_file: MediaDTO?
    let video_file: MediaDTO?

    var mediaURL: String? {
        if let b = banner_file?.file_url, !b.isEmpty { return b }
        return video_file?.file_url
    }
    var isVideo: Bool {
        (banner_file?.file_url?.isEmpty != false) && (video_file?.file_url?.isEmpty == false)
    }
}

struct BusinessInsightsDTO: Decodable {
    let summary_cards: [SummaryCardDTO]?
}

struct SummaryCardDTO: Decodable, Identifiable, Hashable {
    var id: String { key ?? label ?? UUID().uuidString }
    let key: String?
    let label: String?
    let formatted_value: String?
    let detail: String?
    let action_label: String?
    let trend: TrendDTO?

    var subtitle: String? {
        if let t = trend?.label, !t.isEmpty { return t }
        if let d = detail, !d.isEmpty { return d }
        return action_label
    }
    var trendUp: Bool { trend?.direction == "up" }
}

struct TrendDTO: Decodable, Hashable {
    let direction: String?
    let label: String?
}

// MARK: - Product

struct CommonProductData: Decodable {
    let product: ProductDTO?
}

struct ProductDTO: Decodable, Identifiable, Hashable {
    let id: String
    let name: String?
    let sku: String?
    let barcode: String?
    let description: String?
    let brand_name: String?
    let category_title: String?
    let parent_category_title: String?
    let selling_price: String?
    let promotion_price: String?
    let stock: Int?
    let stock_quantity: String?
    let primary_product_image_url: String?
    let image_url: String?

    var priceValue: Double {
        if let s = selling_price, let d = Double(s), d > 0 { return d }
        if let p = promotion_price, let d = Double(p) { return d }
        return 0
    }
    var imageURL: String? {
        if let u = image_url, !u.isEmpty { return u }
        return primary_product_image_url
    }
    var stockCount: Int {
        if let s = stock, s > 0 { return s }
        if let q = stock_quantity, let n = Int(q) { return n }
        return 0
    }
    var inStock: Bool { stockCount > 0 }
}

// MARK: - Cart (GET /api/trader/cart)

/// Note: the cart endpoint returns numeric `id` / prices (e.g. `id: 24`,
/// `selling_price: 20`), whereas the marketplace endpoint returns them as
/// strings. Swift's JSONDecoder will not coerce between the two, so these DTOs
/// decode each numeric-ish field leniently (number *or* numeric string).
struct CartData: Decodable {
    let items: [CartItemDTO]?
    let cart: CartSummaryDTO?

    var lines: [CartItemDTO] { items ?? [] }
    var itemsCount: Int { cart?.items_count ?? lines.count }
    var totalQuantity: Int { cart?.total_quantity ?? lines.reduce(0) { $0 + $1.quantity } }
    var subtotal: Double { cart?.subtotal ?? lines.reduce(0) { $0 + $1.lineTotal } }
    var currencySymbol: String {
        if let s = cart?.currency?.symbol, !s.isEmpty { return s }
        return "R"
    }
}

struct CartSummaryDTO: Decodable {
    let items_count: Int?
    let total_quantity: Int?
    let subtotal: Double?
    let currency: CurrencyDTO?

    enum CodingKeys: String, CodingKey { case items_count, total_quantity, subtotal, currency }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items_count = c.flexInt(.items_count)
        total_quantity = c.flexInt(.total_quantity)
        subtotal = c.flexDouble(.subtotal)
        currency = try? c.decode(CurrencyDTO.self, forKey: .currency)
    }
}

struct CartItemDTO: Decodable {
    let id: String              // cart item id (used for update/delete)
    let productId: String?
    let quantity: Int
    let unitPrice: Double
    let lineTotal: Double
    let inStock: Bool
    let stockQuantity: Int
    let product: CartProductDTO?
    let distributor: CartDistributorDTO?

    enum CodingKeys: String, CodingKey {
        case id, cart_item_id, product_id, quantity, unit_price, line_total
        case in_stock, stock_quantity, product, distributor
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? c.flexString(.cart_item_id) ?? ""
        productId = c.flexString(.product_id)
        quantity = c.flexInt(.quantity) ?? 0
        product = try? c.decode(CartProductDTO.self, forKey: .product)
        unitPrice = c.flexDouble(.unit_price) ?? product?.priceValue ?? 0
        lineTotal = c.flexDouble(.line_total) ?? (unitPrice * Double(quantity))
        inStock = (try? c.decode(Bool.self, forKey: .in_stock)) ?? true
        stockQuantity = c.flexInt(.stock_quantity) ?? 0
        distributor = try? c.decode(CartDistributorDTO.self, forKey: .distributor)
    }
}

struct CartProductDTO: Decodable {
    let id: String?
    let name: String?
    let sku: String?
    let barcode: String?
    let brand_name: String?
    let category_title: String?
    let parent_category_title: String?
    let image_url: String?
    let selling_price: Double?
    let promotion_price: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, sku, barcode, brand_name, category_title
        case parent_category_title, image_url, selling_price, promotion_price
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id)
        name = try? c.decode(String.self, forKey: .name)
        sku = c.flexString(.sku)
        barcode = c.flexString(.barcode)
        brand_name = try? c.decode(String.self, forKey: .brand_name)
        category_title = try? c.decode(String.self, forKey: .category_title)
        parent_category_title = try? c.decode(String.self, forKey: .parent_category_title)
        image_url = try? c.decode(String.self, forKey: .image_url)
        selling_price = c.flexDouble(.selling_price)
        promotion_price = c.flexDouble(.promotion_price)
    }

    var priceValue: Double {
        if let s = selling_price, s > 0 { return s }
        return promotion_price ?? 0
    }
}

struct CartDistributorDTO: Decodable {
    let id: Int?
    let display_name: String?
}

/// Lenient decoders: tolerate a JSON value being a number *or* a numeric string.
private extension KeyedDecodingContainer {
    func flexDouble(_ key: Key) -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key) { return Double(s) }
        return nil
    }
    func flexInt(_ key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? decode(String.self, forKey: key) {
            if let i = Int(s) { return i }
            if let d = Double(s) { return Int(d) }
        }
        return nil
    }
    func flexString(_ key: Key) -> String? {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        if let d = try? decode(Double.self, forKey: key) {
            return d == d.rounded() ? String(Int(d)) : String(d)
        }
        return nil
    }
}

// MARK: - Dashboard (GET /api/trader/dashboard)

/// Mirror of the Android `DashboardData` (network/dto/DashboardData.java). The
/// trader dashboard endpoint is not built on the backend yet, so — exactly like
/// Android's `DashboardFragment` — the screen binds local mock data; these DTOs
/// keep iOS structurally ready for the day the endpoint ships.
struct DashboardData: Decodable {
    let dashboard: Dashboard?

    struct Dashboard: Decodable {
        let meta: DashboardMetaDTO?
        let summary_cards: [DashboardSummaryCardDTO]?
        let overview: [OverviewItemDTO]?
        let revenue_overview: RevenueOverviewDTO?
        let top_selling_categories: TopCategoriesDTO?
        let recent_orders: RecentOrdersDTO?
    }
}

struct DashboardMetaDTO: Decodable {
    let from_date: String?
    let to_date: String?
    let date_range_label: String?
    let compare_from_date: String?
    let compare_to_date: String?
    let compare_period_label: String?
    let currency: CurrencyDTO?
    let is_dummy_data: Bool?
}

struct DashboardSummaryCardDTO: Decodable, Identifiable, Hashable {
    var id: String { key ?? label ?? UUID().uuidString }
    let key: String?
    let label: String?
    let value: Double?
    let formatted_value: String?
    let is_money: Bool?
    let trend: DashboardTrendDTO?
    let compare_label: String?
    let sparkline: [Double]?
    let color: String?
}

struct OverviewItemDTO: Decodable, Identifiable, Hashable {
    var id: String { key ?? label ?? UUID().uuidString }
    let key: String?
    let label: String?
    let value: Int?
    let action_label: String?
    let action_route: String?
}

struct RevenueOverviewDTO: Decodable {
    let title: String?
    let total: Double?
    let formatted_total: String?
    let trend: DashboardTrendDTO?
    let chart: ChartDTO?
}

struct DashboardTrendDTO: Decodable, Hashable {
    let direction: String?
    let percentage: Double?
    let label: String?

    var isUp: Bool { direction?.lowercased() != "down" }
}

struct ChartDTO: Decodable {
    let labels: [String]?
    let values: [Double]?
    let max_value: Double?
    let y_axis_max: String?
}

struct TopCategoriesDTO: Decodable {
    let title: String?
    let items: [CategoryItemDTO]?
    let total: Double?
    let formatted_total: String?
}

struct CategoryItemDTO: Decodable, Identifiable, Hashable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let amount: Double?
    let formatted_amount: String?
    let percentage: Double?
    let color: String?
}

struct RecentOrdersDTO: Decodable {
    let title: String?
    let items: [RecentOrderDTO]?
    let total: Int?
}

struct RecentOrderDTO: Decodable, Identifiable, Hashable {
    var id: String { order_id ?? UUID().uuidString }
    let order_id: String?
    let trader: String?
    let amount: Double?
    let formatted_amount: String?
    let status: String?
    let status_label: String?
    let status_color: String?
    let date: String?
    let formatted_date: String?
}

// MARK: - Address autocomplete / coordinate (Create Account location)

struct AutocompleteData: Decodable {
    let predictions: [AddressSuggestion]?
}

struct AddressSuggestion: Decodable, Identifiable, Hashable {
    var id: String { place_id }
    let place_id: String
    let description: String
}

struct CoordinateData: Decodable {
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let formatted_address: String?

    var lat: Double? { latitude }
    var lng: Double? { longitude }
    var resolvedAddress: String? { formatted_address ?? address }
}
