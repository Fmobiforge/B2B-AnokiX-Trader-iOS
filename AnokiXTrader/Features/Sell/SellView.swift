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

    var body: some View {
        VStack(spacing: 0) {
            header

            // search + scan + QR
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Brand.textSecondary)
                    TextField("Search products by name, barcode or SKU…", text: $searchText)
                        .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
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

            // category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.categories, id: \.self) { c in
                        FilterChip(label: c, selected: c == selectedCategory) { selectedCategory = c }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Brand.surface)

            // product grid
            ScrollView {
                if store.isLoading {
                    ProgressView().padding(.top, 60)
                } else if products.isEmpty {
                    Text("No products available.")
                        .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
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

    private var header: some View {
        HStack(spacing: 12) {
            Button { withAnimation { router.drawerOpen = true } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(Brand.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("POS").font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
                Text("Scan and sell products at your store")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
            Spacer()
            Button { router.presented = .sales } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.textPrimary)
            }
            .accessibilityLabel("Sales History")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Brand.surface)
    }

    private func scannerButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var currentSaleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Current Sale").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    if cart.itemCount > 0 {
                        Text("\(cart.itemCount)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Brand.purple).clipShape(Capsule())
                    }
                }
                Text(Money.rand(cart.subtotal)).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
            Spacer()
            Button("Complete Sale") {
                if cart.isEmpty { toastMsg = "Your cart is empty." } else { showCheckout = true }
            }
            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
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
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                .lineLimit(2).frame(height: 36, alignment: .topLeading)
            if let sku = product.sku, !sku.isEmpty {
                Text("SKU: \(sku)").font(.system(size: 10)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Money.rand(product.price)).font(.system(size: 16, weight: .bold)).foregroundColor(Brand.purple)
                    Text(product.sellable ? "\(product.units) in stock" : "Out of Stock")
                        .font(.system(size: 10, weight: .semibold))
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
