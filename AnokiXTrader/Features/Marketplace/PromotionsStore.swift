import SwiftUI

/// Loads the paginated "Current Promotions" list (GET /api/trader/marketplace/promotions)
/// — the iOS counterpart of the Android `PromotionsActivity` data. `@MainActor` so
/// post-`await` `@Published` writes need no `MainActor.run`.
@MainActor
final class PromotionsStore: ObservableObject {
    @Published var title = "Current Promotions"
    @Published var promotions: [PromotionDTO] = []
    @Published var total = 0
    @Published var loading = false
    @Published var loadingMore = false
    @Published var error: String?

    private var page = 0
    private var totalPages = 1
    private let perPage = 10

    func loadFirst() async {
        guard promotions.isEmpty, !loading else { return }
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
            let result = try await APIClient.shared.getPromotions(page: requested, perPage: perPage)
            if let t = result.title, !t.isEmpty { title = t }
            if let pg = result.pagination {
                page = pg.page
                totalPages = pg.total_pages
                total = pg.total
            }
            let items = result.promotions ?? []
            if reset { promotions = items } else { promotions.append(contentsOf: items) }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load promotions."
        }
    }
}
