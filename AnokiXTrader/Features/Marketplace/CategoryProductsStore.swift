import SwiftUI

/// Loads and filters one category's products (GET /api/trader/marketplace/category) —
/// the iOS counterpart of the Android `CategoryProductsActivity` data + filter state.
/// `@MainActor` (like `MarketStore`) so post-`await` `@Published` writes need no
/// `MainActor.run` wrapping. The cart badge / add-to-cart stay on the shared
/// `MarketStore`; this store only owns the category page.
@MainActor
final class CategoryProductsStore: ObservableObject {
    let categoryId: String

    @Published var page: CategoryPageData?
    @Published var loading = false
    @Published var error: String?

    // Committed filter state (drives the query). Edits happen on working copies in the
    // filter sheet and are committed here on Apply, then `load()` re-queries.
    @Published var selBrands: Set<Int> = []
    @Published var selSubCategories: Set<Int> = []
    @Published var selPackSizes: Set<String> = []
    @Published var onPromotion = false
    @Published var inStock = false
    @Published var minPrice: Double?
    @Published var maxPrice: Double?
    @Published var sortBy = "popularity"

    init(categoryId: String) { self.categoryId = categoryId }

    // MARK: - Derived

    var currency: String { page?.currencySymbol ?? "R" }
    var products: [ProductDTO] { page?.products ?? [] }
    var recentlyPurchased: [ProductDTO] { page?.recently_purchased ?? [] }
    var banners: [BannerDTO] { page?.banners ?? [] }
    var filters: CategoryFiltersDTO? { page?.filters }
    var totalCount: Int { page?.pagination?.total ?? products.count }

    var sortOptions: [SortOptionDTO] {
        if let o = page?.sort_options, !o.isEmpty { return o }
        return CategoryProductsStore.defaultSortOptions
    }
    var sortLabel: String {
        sortOptions.first { $0.value == sortBy }?.label ?? "Popularity"
    }

    /// The Filters badge count — mirrors Android `updateFilterBadge()`.
    var activeFilterCount: Int {
        selBrands.count + selSubCategories.count + selPackSizes.count
            + (onPromotion ? 1 : 0) + (inStock ? 1 : 0)
            + ((minPrice != nil || maxPrice != nil) ? 1 : 0)
    }

    static let defaultSortOptions: [SortOptionDTO] = [
        SortOptionDTO(value: "popularity", label: "Popularity"),
        SortOptionDTO(value: "price_asc", label: "Price: Low to High"),
        SortOptionDTO(value: "price_desc", label: "Price: High to Low"),
        SortOptionDTO(value: "newest", label: "Newest"),
        SortOptionDTO(value: "name_asc", label: "Name: A to Z")
    ]

    // MARK: - Load

    func load() async {
        loading = true
        error = nil
        do {
            let result = try await APIClient.shared.getCategoryProducts(
                categoryId: categoryId,
                brands: csv(selBrands),
                subCategories: csv(selSubCategories),
                packSizes: selPackSizes.isEmpty ? nil : selPackSizes.sorted().joined(separator: ","),
                minPrice: minPrice.map { String(format: "%.2f", $0) },
                maxPrice: maxPrice.map { String(format: "%.2f", $0) },
                onPromotion: onPromotion,
                inStock: inStock,
                sortBy: sortBy)
            page = result
            loading = false
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not load products."
            loading = false
        }
    }

    private func csv(_ ids: Set<Int>) -> String? {
        ids.isEmpty ? nil : ids.sorted().map(String.init).joined(separator: ",")
    }
}
