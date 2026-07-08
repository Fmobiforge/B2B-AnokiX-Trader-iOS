import SwiftUI

/// Sell / POS (Pagamio) — live product grid from `api/trader/pos/products`. Search +
/// category chips filter the grid; "+" builds the Current Sale, the bottom bar opens
/// Complete Sale (`CheckoutView`), and the receipt icon opens Sales History.
struct SellView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var cart: Cart
    @StateObject private var store = PosStore()
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    @State private var showCheckout = false
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

            // search + scan
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

                Button { toastMsg = "Barcode scanner coming soon." } label: {
                    Label("Scan", systemImage: "barcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
                }
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

            // Current Sale bar — above the product list; the VAS section has its own "Sell now".
            currentSaleBar

            // product grid + "Sell Airtime & VAS" section
            ScrollView {
                VStack(spacing: 0) {
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

                    SellVasSection()
                }
            }
            .background(Brand.background)
            .scrollDismissesKeyboard(.interactive)
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showCheckout) { CheckoutView() }
        .task { await store.load() }
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
                Text("Scan and sell products")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Brand.surface)
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

// MARK: - Sell Airtime & VAS (POS section)

/// Live VAS store for the POS "Sell Airtime & VAS" panel — category tree → leaves,
/// products for the selected category, the commission rate and the trader's own
/// number (for "Buy for → Myself"). Endpoints are common (`api/common/vas/*`),
/// wallet-paid — the same feed as the standalone Airtime screen.
@MainActor
final class PosVasStore: ObservableObject {
    @Published var categories: [VasCategoryNode] = []
    @Published var products: [VasProductDTO] = []
    @Published var selectedCategory: VasCategoryNode?
    @Published var selectedProduct: VasProductDTO?
    @Published var categoriesLoading = false
    @Published var productsLoading = false
    @Published var categoriesExpanded = false
    @Published var commissionRate: Double = 0
    @Published var ownPhone = ""

    private static let productLimit = 60

    func loadCategories() async {
        categoriesLoading = true
        do {
            let data = try await APIClient.shared.getVasCategories()
            commissionRate = data.commission_rate
            categories = data.leaves
            if let first = categories.first { await selectCategory(first) }
        } catch {
            categories = []
        }
        categoriesLoading = false
    }

    func selectCategory(_ node: VasCategoryNode) async {
        selectedCategory = node
        selectedProduct = nil
        await loadProducts(node.id)
    }

    func loadProducts(_ categoryId: String) async {
        productsLoading = true
        products = []
        do {
            let data = try await APIClient.shared.getVasProducts(
                category: categoryId, page: 1, limit: Self.productLimit)
            products = data.products
        } catch {
            products = []
        }
        productsLoading = false
    }

    /// The trader's own mobile (base-info) → prefilled when "Buy for → Myself". Best-effort.
    func loadOwnPhone() async {
        if let user = try? await APIClient.shared.getProfileUser() {
            ownPhone = user.phone
        }
    }

    func purchase(msisdn: String, amount: Double) async throws {
        guard let product = selectedProduct, let category = selectedCategory else { return }
        try await APIClient.shared.purchaseVas(
            productId: product.id, msisdn: msisdn, amount: amount,
            sku: product.sku ?? "", name: product.name ?? "", category: category.name)
    }
}

/// POS "Sell Airtime & VAS" section — mirrors the Android `section_sell_vas.xml`:
/// a category picker, a "Select amount" product grid (price-first), the custom-amount
/// input directly under the grid, and a green "Buy for" panel (Myself / Someone else)
/// showing the sell price + estimated commission with a wallet-paid "Sell now".
struct SellVasSection: View {
    @StateObject private var store = PosVasStore()

    @State private var recipient = ""
    @State private var customAmount = ""
    @State private var reference = ""
    @State private var buyForSelf = true
    @State private var isSelling = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let productCols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let categoryGridCols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var currentAmount: Double {
        guard let p = store.selectedProduct else { return 0 }
        if p.isAdHoc { return Double(customAmount.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return p.price
    }
    private var commission: Double { currentAmount * store.commissionRate }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sell Airtime & VAS")
                .font(.system(size: 18, weight: .bold)).foregroundColor(Brand.textPrimary)
            categorySection
            productSection
        }
        .padding(16)
        .task {
            await store.loadOwnPhone()
            await store.loadCategories()
        }
        .onChange(of: store.ownPhone) { newValue in
            if buyForSelf && recipient.isEmpty { recipient = newValue }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: Categories

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("1. Choose a category")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                if store.categories.count > 1 {
                    Button(store.categoriesExpanded ? "Show less" : "View all") {
                        withAnimation { store.categoriesExpanded.toggle() }
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.success)
                }
            }

            if store.categoriesLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if store.categories.isEmpty {
                Text("No categories available.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary).padding(.vertical, 12)
            } else if store.categoriesExpanded {
                LazyVGrid(columns: categoryGridCols, spacing: 10) {
                    ForEach(store.categories) { node in categoryCard(node, fixedWidth: false) }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.categories) { node in categoryCard(node, fixedWidth: true) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .card()
    }

    private func categoryCard(_ node: VasCategoryNode, fixedWidth: Bool) -> some View {
        let selected = node.id == store.selectedCategory?.id
        return Button {
            Task { await store.selectCategory(node) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: AirtimeView.icon(for: node.id, node.name))
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.purple)
                    .frame(width: 36, height: 36)
                    .background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(node.name)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Text("\(node.productCount) \(node.productCount == 1 ? "bundle" : "bundles")")
                    .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            }
            .frame(width: fixedWidth ? 128 : nil, alignment: .leading)
            .frame(maxWidth: fixedWidth ? nil : .infinity, alignment: .leading)
            .padding(12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Products + "Buy for" panel

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Select a product")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            if let c = store.selectedCategory {
                (Text(c.name)
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Brand.textPrimary)
                    + Text(" powered by ")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    + Text("Limes")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Brand.success))
            }

            Text("Select amount")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                .padding(.top, 2)

            if store.productsLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if store.products.isEmpty {
                Text("No products available for this category.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary).padding(.vertical, 16)
            } else {
                LazyVGrid(columns: productCols, spacing: 10) {
                    ForEach(store.products) { product in productCard(product) }
                }
            }

            if store.selectedProduct?.isAdHoc ?? false {
                vasField(title: "Custom amount (R)") {
                    TextField("R e.g. 20", text: $customAmount)
                        .keyboardType(.decimalPad).modifier(VasFieldBox())
                }
            }

            buyForPanel
        }
        .card()
    }

    private func productCard(_ product: VasProductDTO) -> some View {
        let selected = product.id == store.selectedProduct?.id
        let adHoc = product.isAdHoc
        return Button {
            store.selectedProduct = product
            if !adHoc { customAmount = "" }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(adHoc ? "Custom" : Money.rand(product.price))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                        .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Text(product.name ?? "—")
                        .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18)).foregroundColor(Brand.success)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .padding(12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var buyForPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buy for").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)

            HStack(spacing: 10) {
                buyForButton("Myself", selected: buyForSelf) { setBuyFor(true) }
                buyForButton("Someone else", selected: !buyForSelf) { setBuyFor(false) }
            }

            vasField(title: "Recipient mobile number") {
                HStack(spacing: 8) {
                    Image(systemName: "person").foregroundColor(Brand.textSecondary)
                    TextField("073 555 0148", text: $recipient).keyboardType(.phonePad)
                }
                .modifier(VasFieldBox())
            }

            vasField(title: "Optional reference") {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("e.g. invoice, customer name", text: $reference)
                        .modifier(VasFieldBox())
                        .onChange(of: reference) { newValue in
                            if newValue.count > 30 { reference = String(newValue.prefix(30)) }
                        }
                    Text("\(reference.count)/30").font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                }
            }

            Divider().overlay(Brand.success.opacity(0.25))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sell price").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    Text(Money.rand(currentAmount))
                        .font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your commission (est.)").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    Text(Money.rand(commission))
                        .font(.system(size: 20, weight: .bold)).foregroundColor(Brand.success)
                }
            }

            Button {
                sell()
            } label: {
                if isSelling {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Sell now")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSelling)

            Text("Paid from your anokiX wallet. Change how you pay in Settings → Preferences.")
                .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
        }
        .padding(14)
        .background(Brand.success.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Brand.success.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func buyForButton(_ title: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selected ? Brand.success : Brand.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(selected ? Brand.successBg : Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 1.5 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func vasField<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            content()
        }
    }

    // MARK: Actions

    private func setBuyFor(_ self_: Bool) {
        buyForSelf = self_
        recipient = self_ ? store.ownPhone : ""
    }

    private func sell() {
        guard validate() else { return }
        let msisdn = recipient.trimmingCharacters(in: .whitespaces)
        let amount = currentAmount
        isSelling = true
        Task {
            do {
                try await store.purchase(msisdn: msisdn, amount: amount)
                isSelling = false
                store.selectedProduct = nil
                customAmount = ""
                reference = ""
                present("Sale successful", "Your Airtime & VAS sale has been submitted.")
            } catch {
                isSelling = false
                present("Sell now",
                        (error as? LocalizedError)?.errorDescription ?? "Sale failed. Please try again.")
            }
        }
    }

    private func validate() -> Bool {
        guard store.selectedProduct != nil else {
            present("Check your details", "Please select a product first."); return false
        }
        let msisdn = recipient.trimmingCharacters(in: .whitespaces)
        if msisdn.isEmpty {
            present("Check your details", "Please enter the recipient's mobile number."); return false
        }
        if !AirtimeView.isValidMsisdn(msisdn) {
            present("Check your details", "Enter a valid mobile number, e.g. 082 123 4567."); return false
        }
        if currentAmount <= 0 {
            present("Check your details", "Please enter a valid amount greater than R0.00."); return false
        }
        return true
    }

    private func present(_ title: String, _ message: String) {
        alertTitle = title; alertMessage = message; showAlert = true
    }
}

/// Outlined input box for the POS VAS fields (mirrors AirtimeView's private FieldBox).
private struct VasFieldBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
