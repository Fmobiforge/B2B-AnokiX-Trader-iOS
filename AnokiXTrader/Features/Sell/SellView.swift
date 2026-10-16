import SwiftUI

/// POS (Pagamio) — the till screen: a live product grid from `api/trader/pos/products`
/// with search + category filters. "+" builds the Current Sale, the bottom bar opens
/// Complete Sale (`CheckoutView`), and the receipt icon opens Sales History (`SalesView`).
///
/// POS-only by design: Airtime & VAS lives on its own screen (`AirtimeView`), not here.
struct SellView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var cart: Cart
    @StateObject private var store = PosStore()
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    @State private var showCheckout = false
    @State private var scanMode: PosScanMode?
    @State private var toastMsg: String?

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var products: [PosProductDTO] {
        store.products.filter { p in
            let catOk = selectedCategory == "All" || p.category == selectedCategory
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            let searchOk = q.isEmpty
                || (p.name?.lowercased().contains(q) ?? false)
                || (p.sku?.lowercased().contains(q) ?? false)
                || (p.barcode?.lowercased().contains(q) ?? false)
            return catOk && searchOk
        }
    }

    // Only the header (the way to the drawer) and the Current Sale bar (the way to check
    // out) stay pinned. The search row and the category chips scroll away with the grid —
    // stacked as fixed chrome they left barely one row of products visible on a short
    // screen. Same single-scroll arrangement as FinancesView.
    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    searchRow
                    categoryChips
                    productGrid
                }
            }
            .background(Brand.background)
            .scrollDismissesKeyboard(.interactively)

            // Current Sale bar — pinned under the grid; opens Complete Sale.
            currentSaleBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showCheckout) { CheckoutView() }
        // The sheet reads the grid this view already holds — no second products call.
        .sheet(item: $scanMode) { mode in
            PosScanView(mode: mode, products: store.products, cart: cart)
                .presentationDetents([.large])
        }
        // Reloaded on every appearance: a committed sale reduces on-hand stock.
        .task(id: showCheckout) { if !showCheckout { await store.load() } }
        .toast($toastMsg)
    }

    // MARK: - Scrolling chrome

    /// search + scan + QR
    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Brand.textSecondary)
                TextField("Search products by name, barcode or SKU…", text: $searchText)
                    .font(.app(13)).foregroundColor(Brand.textPrimary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12).frame(height: 44)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            scannerButton("Scan", icon: "barcode.viewfinder") { scanMode = .barcode }
            scannerButton("QR", icon: "qrcode.viewfinder") { scanMode = .qr }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Brand.surface)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.categories, id: \.self) { c in
                    FilterChip(label: c, selected: c == selectedCategory) { selectedCategory = c }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Brand.surface)
    }

    @ViewBuilder
    private var productGrid: some View {
        if store.isLoading {
            ProgressView().padding(.top, 60)
        } else if products.isEmpty {
            Text("No products available.")
                .font(.app(14)).foregroundColor(Brand.textSecondary)
                .padding(.top, 60)
        } else {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(products) { p in
                    PosProductCard(product: p) {
                        cart.add(product: p)
                        toastMsg = "Added \(p.name ?? "")"
                    }
                }
            }
            .padding(12)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            // MainTabView's ZStack already animates on `drawerOpen`; flipping the flag is
            // all this needs, and it avoids nesting one animation inside another.
            Button { router.drawerOpen = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .tapTarget()
            }
            .accessibilityLabel("Open menu")
            VStack(alignment: .leading, spacing: 2) {
                Text("POS").font(.app(20, .bold)).foregroundColor(Brand.textPrimary)
                Text("Scan and sell products at your store")
                    .font(.app(12)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
            Spacer()
            Button { router.presented = .sales } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .tapTarget()
            }
            .accessibilityLabel("Sales History")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Brand.surface)
    }

    private func scannerButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.app(13, .semibold)).foregroundColor(.white)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var currentSaleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Current Sale").font(.app(12)).foregroundColor(Brand.textSecondary)
                    if cart.itemCount > 0 {
                        Text("\(cart.itemCount)")
                            .font(.app(11, .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Brand.purple).clipShape(Capsule())
                    }
                }
                Text(Money.rand(cart.subtotal)).font(.app(20, .bold)).foregroundColor(Brand.textPrimary)
            }
            Spacer()
            Button("Complete Sale") {
                if cart.isEmpty { toastMsg = "Your cart is empty." } else { showCheckout = true }
            }
            .font(.app(15, .semibold)).foregroundColor(.white)
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Brand.surface.shadow(.drop(color: .black.opacity(0.08), radius: 6, y: 2)))
    }
}

struct PosProductCard: View {
    let product: PosProductDTO
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(url: MediaUrls.resolve(product.image_url))
                .frame(height: 84)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(product.name ?? "")
                .font(.app(13, .semibold)).foregroundColor(Brand.textPrimary)
                .lineLimit(2).frame(height: 36, alignment: .topLeading)
            if let sku = product.sku, !sku.isEmpty {
                Text("SKU: \(sku)").font(.app(10)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Money.rand(product.price)).font(.app(16, .bold)).foregroundColor(Brand.purple)
                    Text(product.sellable ? "\(product.units) in stock" : "Out of Stock")
                        .font(.app(10, .semibold))
                        .foregroundColor(product.sellable ? Brand.success : Brand.danger)
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(product.sellable ? Brand.purple : Brand.border)
                        .clipShape(Circle())
                }
                .disabled(!product.sellable)
            }
        }
        .card(padding: 10)
    }
}
