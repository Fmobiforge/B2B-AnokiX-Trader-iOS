import SwiftUI

// MARK: - Store

/// Airtime & VAS (Limes, live). Loads the category tree (flattened to purchasable
/// leaves), the selected category's products, and the KPI summary + recent
/// transactions. Mirrors the Android `AirtimeActivity`. Endpoints are common
/// (`api/common/vas/*`) and wallet-paid.
@MainActor
final class AirtimeStore: ObservableObject {
    @Published var categories: [VasCategoryNode] = []
    @Published var products: [VasProductDTO] = []
    @Published var transactions: [VasTransactionDTO] = []
    @Published var summary: VasSummaryDTO?

    @Published var selectedCategory: VasCategoryNode?
    @Published var selectedProduct: VasProductDTO?

    @Published var categoriesLoading = false
    @Published var productsLoading = false
    @Published var categoriesExpanded = false

    private static let productLimit = 60
    private static let txnPerPage = 20

    /// KPI summary + recent transactions. Silent on failure (dashboard is secondary).
    func loadTransactions() async {
        do {
            let data = try await APIClient.shared.getVasTransactions(page: 1, perPage: Self.txnPerPage)
            transactions = data.transactions
            summary = data.summary
        } catch {
            transactions = []
        }
    }

    /// Category tree → selectable leaves; auto-selects the first leaf and loads its products.
    func loadCategories() async {
        categoriesLoading = true
        do {
            let data = try await APIClient.shared.getVasCategories()
            categories = data.leaves
            if let first = categories.first {
                await selectCategory(first)
            }
        } catch {
            categories = []
        }
        categoriesLoading = false
    }

    /// Switch category: reset the product selection and load the new category's products.
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

    /// Buy the selected product; throws with the network's reason on failure.
    func purchase(msisdn: String, amount: Double) async throws {
        guard let product = selectedProduct, let category = selectedCategory else { return }
        try await APIClient.shared.purchaseVas(
            productId: product.id,
            msisdn: msisdn,
            amount: amount,
            sku: product.sku ?? "",
            name: product.name ?? "",
            category: category.name)
    }

    /// After a successful purchase: clear the product/ref state and refresh the dashboard.
    func onPurchaseComplete() async {
        selectedProduct = nil
        await loadTransactions()
    }
}

// MARK: - View

/// Airtime & VAS screen (hosted inside `ModuleHost`'s NavigationStack). KPI cards,
/// a category picker (expandable), a product grid and a wallet-paid order summary —
/// a SwiftUI port of the Android `activity_airtime.xml` / `AirtimeActivity`.
struct AirtimeView: View {
    @StateObject private var store = AirtimeStore()

    @State private var recipient = ""
    @State private var customAmount = ""
    @State private var reference = ""

    @State private var isPurchasing = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let productCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let kpiCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let categoryGridCols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    /// The amount that will be charged: ad-hoc → custom input; fixed → the product price.
    private var currentAmount: Double {
        guard let p = store.selectedProduct else { return 0 }
        if p.isAdHoc {
            return Double(customAmount.trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return p.price
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Buy airtime, data and digital services instantly. Powered by Limes.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)

                kpiGrid
                categorySection
                productSection
                orderSummary
                transactionsSection
            }
            .padding(16)
        }
        .background(Brand.background)
        .scrollDismissesKeyboard(.interactively)
        .task {
            await store.loadTransactions()
            await store.loadCategories()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: KPI

    private var kpiGrid: some View {
        LazyVGrid(columns: kpiCols, spacing: 12) {
            StatTile(label: "VAS spend · today", value: Money.rand(store.summary?.sales_today ?? 0),
                     valueColor: Brand.purple, icon: "arrow.up.right.circle.fill", iconTint: Brand.success)
            StatTile(label: "Transactions · today", value: "\(Int(store.summary?.count_today ?? 0))",
                     icon: "arrow.left.arrow.right", iconTint: Brand.info)
            StatTile(label: "Airtime & data · month", value: Money.rand(store.summary?.commission_month ?? 0),
                     icon: "antenna.radiowaves.left.and.right", iconTint: Brand.warning)
            StatTile(label: "Wallet balance", value: Money.rand(store.summary?.wallet_balance ?? 0),
                     valueColor: Brand.purple, icon: "creditcard.fill", iconTint: Brand.purple)
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
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                }
            }

            if store.categoriesLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if store.categories.isEmpty {
                Text("No categories available.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    .padding(.vertical, 12)
            } else if store.categoriesExpanded {
                LazyVGrid(columns: categoryGridCols, spacing: 12) {
                    ForEach(store.categories) { node in
                        categoryCard(node, fixedWidth: false)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.categories) { node in
                            categoryCard(node, fixedWidth: true)
                        }
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
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: Self.icon(for: node.id, node.name))
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.purple)
                    .frame(width: 36, height: 36)
                    .background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(node.name)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text(bundleCount(node.productCount))
                    .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            }
            .frame(width: fixedWidth ? 128 : nil, alignment: .center)
            .frame(maxWidth: fixedWidth ? nil : .infinity, alignment: .center)
            .padding(12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Products

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

            if store.productsLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if store.products.isEmpty {
                Text("No products available for this category.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: productCols, spacing: 12) {
                    ForEach(store.products) { product in
                        productCard(product)
                    }
                }
            }
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
                    Text(adHoc ? "Custom" : (product.name ?? "—"))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                        .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Text(adHoc ? (product.name ?? "") : Money.rand(product.price))
                        .font(.system(size: 12, weight: adHoc ? .regular : .semibold))
                        .foregroundColor(adHoc ? Brand.textSecondary : Brand.purple)
                        .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18)).foregroundColor(Brand.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Order summary

    private var orderSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Order summary")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)

            field(title: "Recipient") {
                TextField("082 123 4567", text: $recipient)
                    .keyboardType(.phonePad)
                    .modifier(FieldBox())
            }

            if store.selectedProduct?.isAdHoc ?? false {
                field(title: "Custom amount (R)") {
                    TextField("R e.g. 20", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .modifier(FieldBox())
                }
            }

            field(title: "Optional reference") {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("e.g. invoice, customer name", text: $reference)
                        .modifier(FieldBox())
                        .onChange(of: reference) { newValue in
                            if newValue.count > 30 { reference = String(newValue.prefix(30)) }
                        }
                    Text("\(reference.count)/30")
                        .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                }
            }

            Divider()

            summaryRow(
                label: store.selectedProduct?.name ?? "No product selected",
                labelColor: store.selectedProduct == nil ? Brand.textSecondary : Brand.textPrimary,
                value: store.selectedProduct == nil ? "" : Money.rand(currentAmount))
            summaryRow(label: "Service fee", labelColor: Brand.textSecondary, value: Money.rand(0))
            summaryRow(label: "Total", labelColor: Brand.textPrimary,
                       value: Money.rand(currentAmount), emphasised: true)

            Button {
                purchase()
            } label: {
                if isPurchasing {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Buy now")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPurchasing)

            Text("Paid from your anokiX wallet. Change how you pay in Settings → Preferences.")
                .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
        }
        .card()
    }

    private func summaryRow(label: String, labelColor: Color, value: String,
                            emphasised: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: emphasised ? 16 : 14, weight: emphasised ? .bold : .regular))
                .foregroundColor(emphasised ? Brand.purple : labelColor)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(size: emphasised ? 16 : 14, weight: emphasised ? .bold : .regular))
                .foregroundColor(emphasised ? Brand.purple : Brand.textPrimary)
        }
    }

    private func field<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            content()
        }
    }

    // MARK: Transactions

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent VAS transactions")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            if store.transactions.isEmpty {
                Text("No transactions yet.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.transactions) { txn in
                        transactionRow(txn)
                        if txn.id != store.transactions.last?.id { Divider() }
                    }
                }
            }
        }
        .card()
    }

    private func transactionRow(_ txn: VasTransactionDTO) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(txn.name ?? "—")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                Text("\(Self.formatNumber(txn.msisdn)) · \(Self.formatTime(txn.created_at))")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.rand(Double(txn.amount ?? "") ?? 0))
                    .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                statusPill(txn.status)
            }
        }
        .padding(.vertical, 12)
    }

    private func statusPill(_ status: String?) -> some View {
        let style = Self.statusStyle(status)
        return Text(style.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(style.fg)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(style.bg).clipShape(Capsule())
    }

    // MARK: Purchase flow

    private func purchase() {
        guard validate() else { return }
        let msisdn = recipient.trimmingCharacters(in: .whitespaces)
        let amount = currentAmount
        isPurchasing = true
        Task {
            do {
                try await store.purchase(msisdn: msisdn, amount: amount)
                isPurchasing = false
                await store.onPurchaseComplete()
                customAmount = ""
                reference = ""
                present("Purchase successful",
                        "Your VAS purchase has been submitted. Check Recent VAS transactions for the outcome.")
            } catch {
                isPurchasing = false
                present("Buy now",
                        (error as? LocalizedError)?.errorDescription ?? "Purchase failed. Please try again.")
            }
        }
    }

    /// Validate the order; on the first problem, prompt and return false.
    private func validate() -> Bool {
        guard store.selectedProduct != nil else {
            present("Check your details", "Please select a product first."); return false
        }
        let msisdn = recipient.trimmingCharacters(in: .whitespaces)
        if msisdn.isEmpty {
            present("Check your details", "Please enter the recipient's mobile number."); return false
        }
        if !Self.isValidMsisdn(msisdn) {
            present("Check your details", "Enter a valid mobile number, e.g. 082 123 4567."); return false
        }
        if currentAmount <= 0 {
            present("Check your details", "Please enter a valid amount greater than R0.00."); return false
        }
        return true
    }

    private func present(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: Helpers

    private func bundleCount(_ n: Int) -> String {
        "\(n) \(n == 1 ? "bundle" : "bundles")"
    }

    /// SA mobile number: 10 digits (0xxxxxxxxx) or 11 digits (27xxxxxxxxx).
    static func isValidMsisdn(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        return (digits.count == 10 && digits.hasPrefix("0"))
            || (digits.count == 11 && digits.hasPrefix("27"))
    }

    /// 27821234567 / 0821234567 → "082 123 4567" when it resolves to a 10-digit local number.
    static func formatNumber(_ msisdn: String?) -> String {
        guard let msisdn else { return "" }
        var digits = msisdn.filter(\.isNumber)
        if digits.hasPrefix("27") && digits.count == 11 {
            digits = "0" + digits.dropFirst(2)
        }
        if digits.count == 10 {
            let a = digits.prefix(3)
            let b = digits.dropFirst(3).prefix(3)
            let c = digits.dropFirst(6)
            return "\(a) \(b) \(c)"
        }
        return msisdn
    }

    private static let txnInFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static let txnTimeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    static func formatTime(_ createdAt: String?) -> String {
        guard let createdAt else { return "" }
        if let d = txnInFmt.date(from: createdAt) { return txnTimeFmt.string(from: d) }
        return createdAt
    }

    /// Status pill label + colours, mirroring the Android `styleStatus`.
    static func statusStyle(_ status: String?) -> (label: String, fg: Color, bg: Color) {
        let s = (status ?? "").lowercased()
        if s.contains("fail") || s.contains("error") || s.contains("declin") {
            return ("Failed", Brand.danger, Brand.dangerBg)
        }
        if s.contains("success") || s.contains("complete") || s.contains("paid") {
            return ("Success", Brand.success, Brand.successBg)
        }
        let raw = status ?? ""
        let label = raw.isEmpty ? "Pending" : raw.prefix(1).uppercased() + raw.dropFirst()
        return (label, Brand.purple, Brand.purpleLight)
    }

    /// Category id/name → an SF Symbol, mirroring the Android `VasIcons`.
    static func icon(for id: String?, _ name: String?) -> String {
        let key = ((id ?? "") + " " + (name ?? "")).lowercased()
        if key.contains("whatsapp") || key.contains("sms") || key.contains("message") { return "message.fill" }
        if key.contains("data") || key.contains("fwa") || key.contains("wifi") { return "wifi" }
        if key.contains("voice") || key.contains("airtime") || key.contains("call") { return "phone.fill" }
        if key.contains("service") || key.contains("fee") || key.contains("wallet") { return "creditcard.fill" }
        let bundleKeys = ["combo", "bundle", "subscription", "package", "gsm", "flte",
                          "supplementary", "choose", "recharge", "convert", "day", "week"]
        if bundleKeys.contains(where: { key.contains($0) }) { return "square.grid.2x2.fill" }
        return "antenna.radiowaves.left.and.right"
    }
}

/// Standard outlined input box used across the Order summary fields.
private struct FieldBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
