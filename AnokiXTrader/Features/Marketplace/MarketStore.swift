import SwiftUI

/// Currency formatting with thousands grouping (Swift's C `String(format:)` has
/// no `,` grouping flag, so we use NumberFormatter).
enum CurrencyFmt {
    static func format(_ value: Double, symbol: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return symbol + (f.string(from: NSNumber(value: value)) ?? "0.00")
    }
}

/// A local marketplace cart line (source of truth for the badge / My Cart),
/// mirroring the Android `MarketCart`.
struct MarketCartLine: Identifiable, Hashable {
    let id: String          // product id
    let name: String
    let imageURL: String?
    let barcode: String?
    let sku: String?
    var unitPrice: Double
    var qty: Int
    var cartItemId: String?
    var distributorId: String?
    /// Whether this line is selected for checkout (default true).
    var selected: Bool = true

    var lineTotal: Double { unitPrice * Double(qty) }
}

/// Loads the trader marketplace from the API and holds the local cart.
/// Process-wide singleton — mirrors Android `MarketCart` (badge + My Cart source of truth).
@MainActor
final class MarketStore: ObservableObject {
    static let shared = MarketStore()

    private init() {}

    @Published var data: MarketplaceData?
    /// Portal sections read leniently from the same marketplace response.
    @Published var extras = MarketplaceExtras.empty
    @Published var categories: [ProductCategoryDTO] = []
    @Published var loading = false
    @Published var error: String?
    @Published var selectedDistributorId: String?
    @Published private(set) var cart: [MarketCartLine] = []
    /// Header badge count — mirrors Android `MarketCart.itemCount()` / `total_quantity`.
    @Published private(set) var cartBadgeCount = 0

    var currency: String { data?.currencySymbol ?? "R" }
    var cartCount: Int { cartBadgeCount }
    var cartSubtotal: Double { cart.reduce(0) { $0 + $1.lineTotal } }
    var parentCategories: [ProductCategoryDTO] { categories.filter { $0.parent_id == nil } }

    // MARK: - Checkout selection

    var selectedLines: [MarketCartLine] { cart.filter { $0.selected } }
    var selectedSubtotal: Double { selectedLines.reduce(0) { $0 + $1.lineTotal } }

    /// Toggle whether a line is included in the next order (kept in the cart either way).
    func toggleSelected(_ id: String) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        cart[idx].selected.toggle()
    }

    func loadAll() async {
        await load(distributorId: selectedDistributorId)
        await loadCategories()
    }

    func load(distributorId: String?) async {
        loading = true
        error = nil
        do {
            let (result, sections) = try await APIClient.shared.getMarketplaceFull(distributorId: distributorId)
            data = result
            extras = sections
            if let sel = result.selected_distributor { selectedDistributorId = String(sel.id) }
            loading = false
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? "Could not load marketplace."
            self.error = msg
            loading = false
        }
    }

    func loadCategories() async {
        if let ref = try? await APIClient.shared.getReference() {
            categories = ref.product_categories ?? []
        }
    }

    func selectDistributor(_ id: Int) {
        let idStr = String(id)
        guard idStr != selectedDistributorId else { return }
        selectedDistributorId = idStr
        Task {
            await load(distributorId: idStr)
            if !activeSearch.isEmpty { _ = await search(activeSearch) }
        }
    }

    // MARK: - Campaign analytics (portal parity)

    /// The campaign the trader last opened. Like the portal, later product views on the
    /// marketplace are attributed to it.
    private(set) var lastCampaignId: Int?

    func trackCampaignOpen(_ campaignId: Int) {
        guard campaignId > 0 else { return }
        lastCampaignId = campaignId
        Task { await APIClient.shared.recordCampaignClick(campaignId) }
    }

    /// Records a product view against `campaignId`, or failing that the last campaign opened.
    func trackProductView(_ productId: String, campaignId: Int? = nil) {
        guard let cid = campaignId ?? lastCampaignId, cid > 0 else { return }
        Task { await APIClient.shared.recordCampaignProductView(campaignId: cid, productId: productId) }
    }

    // MARK: - Search (api/trader/marketplace/search)

    /// The query whose results are on screen ("" when not searching).
    @Published private(set) var activeSearch = ""
    @Published private(set) var searchResults: [ProductDTO] = []
    @Published private(set) var searchTotal = 0
    @Published private(set) var searching = false
    @Published private(set) var searchError: String?

    /// Runs a search and returns its products. A response for a query the user has since
    /// replaced is dropped, so fast typing never shows stale results.
    @discardableResult
    func search(_ raw: String) async -> [ProductDTO] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { clearSearch(); return [] }
        activeSearch = query
        searching = true
        searchError = nil
        do {
            let result = try await APIClient.shared.searchMarketplace(query: query,
                                                                     distributorId: selectedDistributorId)
            guard query == activeSearch else { return [] }
            let products = result.products ?? []
            searchResults = products
            searchTotal = max(result.pagination?.total ?? 0, products.count)
            searching = false
            return products
        } catch {
            guard query == activeSearch else { return [] }
            searchResults = []
            searchTotal = 0
            searching = false
            searchError = (error as? LocalizedError)?.errorDescription ?? "Failed to search products."
            return []
        }
    }

    func clearSearch() {
        activeSearch = ""
        searchResults = []
        searchTotal = 0
        searching = false
        searchError = nil
    }

    // MARK: - Cart

    /// Pull the authoritative cart from GET /api/trader/cart and rebuild the local
    /// lines (so the badge, My Cart, and totals reflect the server, and each line
    /// carries its server-assigned cart item id). Keeps the local mirror on failure,
    /// matching Android `MarketplaceActivity.refreshCart()`.
    func refreshCart() async {
        do {
            let data = try await APIClient.shared.getCart()
            let lines: [MarketCartLine] = data.lines.compactMap { item in
                guard item.quantity > 0 else { return nil }
                let p = item.product
                let pid = p?.id ?? item.productId ?? item.id
                let distId = item.distributor?.id.map { String($0) }
                return MarketCartLine(id: pid, name: p?.name ?? "",
                                      imageURL: p?.image_url, barcode: p?.barcode, sku: p?.sku,
                                      unitPrice: item.unitPrice, qty: item.quantity,
                                      cartItemId: item.id, distributorId: distId)
            }
            cart = lines
            cartBadgeCount = data.totalQuantity > 0
                ? data.totalQuantity
                : lines.reduce(0) { $0 + $1.qty }
        } catch {
            // Keep the local mirror on failure (same as Android).
        }
    }

    private func syncBadgeFromCart() {
        cartBadgeCount = cart.reduce(0) { $0 + $1.qty }
    }

    @discardableResult
    func addToCart(_ product: ProductDTO, qty: Int) -> MarketCartLine {
        let price = product.priceValue
        if let idx = cart.firstIndex(where: { $0.id == product.id }) {
            cart[idx].qty += qty
            cart[idx].unitPrice = price
            syncAdd(product, qty: qty, price: price)
            syncBadgeFromCart()
            return cart[idx]
        }
        let line = MarketCartLine(id: product.id, name: product.name ?? "",
                                  imageURL: product.imageURL, barcode: product.barcode,
                                  sku: product.sku, unitPrice: price, qty: qty, cartItemId: nil)
        cart.append(line)
        syncAdd(product, qty: qty, price: price)
        syncBadgeFromCart()
        return line
    }

    func setQty(_ id: String, _ qty: Int) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        if qty <= 0 {
            let removed = cart.remove(at: idx)
            syncDelete(removed)
        } else {
            cart[idx].qty = qty
            syncUpdate(cart[idx])
        }
        syncBadgeFromCart()
    }

    func remove(_ id: String) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        let removed = cart.remove(at: idx)
        syncDelete(removed)
        syncBadgeFromCart()
    }

    // Server sync, then re-pull so the local cart reconciles with the backend
    // (captures cart item ids and authoritative totals).
    private func syncAdd(_ product: ProductDTO, qty: Int, price: Double) {
        Task {
            try? await APIClient.shared.addToCart(productId: product.id, quantity: qty,
                                                  unitPrice: price, barcode: product.barcode,
                                                  sku: product.sku)
            await refreshCart()
        }
    }
    private func syncUpdate(_ line: MarketCartLine) {
        guard let cid = line.cartItemId else { return }
        Task {
            try? await APIClient.shared.updateCartItem(cartItemId: cid, quantity: line.qty,
                                                       unitPrice: line.unitPrice)
            await refreshCart()
        }
    }
    private func syncDelete(_ line: MarketCartLine) {
        guard let cid = line.cartItemId else { return }
        Task {
            try? await APIClient.shared.deleteCartItem(cartItemId: cid)
            await refreshCart()
        }
    }
}
