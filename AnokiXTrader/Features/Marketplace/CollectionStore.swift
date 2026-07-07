import SwiftUI

/// Loads a paginated marketplace collection (GET /api/trader/marketplace/collection)
/// — the iOS counterpart of the Android `CollectionActivity` data. `@MainActor` so
/// post-`await` `@Published` writes need no `MainActor.run`. Pages accumulate as the
/// user scrolls; the cart lives on the shared `MarketStore`.
@MainActor
final class CollectionStore: ObservableObject {
    let type: String

    @Published var title: String
    @Published var products: [ProductDTO] = []
    @Published var total = 0
    @Published var currency = "R"
    @Published var loading = false
    @Published var loadingMore = false
    @Published var error: String?

    private var page = 0
    private var totalPages = 1
    private let perPage = 20

    init(type: String, title: String) {
        self.type = type
        self.title = title
    }

    var canLoadMore: Bool { page < totalPages }

    func loadFirst() async {
        guard products.isEmpty, !loading else { return }
        loading = true
        error = nil
        await fetch(page: 1, reset: true)
        loading = false
    }

    func loadMore() async {
        guard !loading, !loadingMore, page < totalPages else { return }
        loadingMore = true
        await fetch(page: page + 1, reset: false)
        loadingMore = false
    }

    private func fetch(page requested: Int, reset: Bool) async {
        do {
            let result = try await APIClient.shared.getCollection(type: type, page: requested, perPage: perPage)
            currency = result.currencySymbol
            if let t = result.title, !t.isEmpty { title = t }
            if let pg = result.pagination {
                page = pg.page
                totalPages = pg.total_pages
                total = pg.total
            }
            let items = result.products ?? []
            if reset { products = items } else { products.append(contentsOf: items) }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load products."
        }
    }
}
