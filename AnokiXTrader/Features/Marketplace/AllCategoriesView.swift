import SwiftUI

/// Marketplace › "View All" categories chooser — iOS counterpart of the Android
/// `AllCategoriesActivity`. Shows every top-level product category (from the shared
/// `MarketStore.parentCategories`, loaded via the reference endpoint) in a grid with a
/// local keyword filter. Tapping a category pushes `CategoryProductsView`.
struct AllCategoriesView: View {
    @ObservedObject var store: MarketStore
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var showCart = false

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private var filtered: [ProductCategoryDTO] {
        let all = store.parentCategories.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            MarketSubHeader(title: "All Categories", cartBadge: store.cartBadgeCount,
                            onBack: { dismiss() }, onCart: { showCart = true })
            searchField
            content
        }
        .background(Brand.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ProductCategoryDTO.self) { c in
            CategoryProductsView(category: c, store: store)
        }
        .sheet(isPresented: $showCart) { CartView(store: store) }
        .task {
            if store.categories.isEmpty { await store.loadCategories() }
            await store.refreshCart()
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.dark)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(Brand.textSecondary)
            TextField("Search categories…", text: $search).font(.system(size: 14))
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(Brand.surfaceVariant)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.top, 12)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 34)).foregroundColor(Brand.textTertiary)
                Text(store.categories.isEmpty ? "Loading categories…" : "No categories found")
                    .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { c in
                        NavigationLink(value: c) { CategoryTile(category: c) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Category tile

private struct CategoryTile: View {
    let category: ProductCategoryDTO
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: CategoryIcon.symbol(for: category))
                .font(.system(size: 22)).foregroundColor(Brand.purple)
                .frame(width: 56, height: 56).background(Brand.purpleLight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(category.title)
                .font(.system(size: 11, weight: .medium)).foregroundColor(Brand.textPrimary)
                .multilineTextAlignment(.center).lineLimit(2)
                .frame(height: 30, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.border, lineWidth: 1))
    }
}

// MARK: - Shared purple sub-header (back + title + cart), reused by CategoryProductsView

struct MarketSubHeader: View {
    let title: String
    let cartBadge: Int
    let onBack: () -> Void
    let onCart: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCart) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "cart").font(.system(size: 22)).foregroundColor(.white)
                        .frame(width: 24, height: 24)
                    if cartBadge > 0 {
                        Text(cartBadge > 99 ? "99+" : "\(cartBadge)")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Brand.danger).clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
                .frame(width: 48, height: 48).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.bottom, 8).frame(minHeight: 44)
        .background(
            LinearGradient(colors: [Brand.purpleDark, Brand.purple],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Category → SF Symbol mapping (mirrors Android CategoryIcons)

enum CategoryIcon {
    static func symbol(for c: ProductCategoryDTO) -> String {
        let key = (c.slug ?? c.title).lowercased()
        if key.contains("bever") || key.contains("drink") || key.contains("juice") { return "cup.and.saucer.fill" }
        if key.contains("dairy") || key.contains("milk") { return "drop.fill" }
        if key.contains("frozen") { return "snowflake" }
        if key.contains("snack") || key.contains("confection") { return "takeoutbag.and.cup.and.straw.fill" }
        if key.contains("fruit") || key.contains("veg") || key.contains("fresh") { return "leaf.fill" }
        if key.contains("bak") || key.contains("bread") { return "birthday.cake.fill" }
        if key.contains("meat") || key.contains("butcher") { return "fork.knife" }
        if key.contains("pharm") || key.contains("health") || key.contains("medic") { return "cross.case.fill" }
        if key.contains("clean") || key.contains("household") || key.contains("home") { return "house.fill" }
        if key.contains("baby") { return "figure.and.child.holdinghands" }
        if key.contains("grocery") || key.contains("food") { return "basket.fill" }
        return "square.grid.2x2.fill"
    }
}
