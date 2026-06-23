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

    var lineTotal: Double { unitPrice * Double(qty) }
}

/// Loads the trader marketplace from the API and holds the local cart.
/// Process-wide singleton — mirrors Android `MarketCart` (badge + My Cart source of truth).
@MainActor
final class MarketStore: ObservableObject {
    static let shared = MarketStore()

    private init() {}

    @Published var data: MarketplaceData?
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

    func loadAll() async {
        await load(distributorId: selectedDistributorId)
        await loadCategories()
    }

    func load(distributorId: String?) async {
        loading = true
        error = nil
        do {
            let result = try await APIClient.shared.getMarketplace(distributorId: distributorId)
            data = result
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
        Task { await load(distributorId: idStr) }
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
                return MarketCartLine(id: pid, name: p?.name ?? "",
                                      imageURL: p?.image_url, barcode: p?.barcode, sku: p?.sku,
                                      unitPrice: item.unitPrice, qty: item.quantity, cartItemId: item.id)
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
