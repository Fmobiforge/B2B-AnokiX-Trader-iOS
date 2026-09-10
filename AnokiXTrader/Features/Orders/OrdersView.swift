import SwiftUI

struct OrdersView: View {
    @StateObject private var store = OrdersStore()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showDatePicker = false

    private let statusKeys = ["all", "pending", "accepted", "picking", "packing",
                              "out_for_delivery", "delivered", "cancelled", "failed"]
    private let statusTitles = ["All Orders", "Pending", "Accepted", "Picking", "Packing",
                                "Out for Delivery", "Delivered", "Cancelled", "Failed"]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Orders", subtitle: "Track and manage your orders")

            // The search box, distributor/date filters and the status tabs scroll away
            // with the list: stacked as fixed chrome under the header they left roughly
            // two orders visible on a short screen. The header stays pinned (it is the
            // way to the drawer) and so does the pagination bar.
            ScrollView {
                VStack(spacing: 0) {
                    filterBar
                    statusTabs
                    Divider()
                    content
                }
            }
            .background(Brand.background)

            paginationBar
        }
        .navigationBarHidden(true)
        .navigationDestination(for: OrderDTO.self) { OrderDetailView(order: $0) }
        .task { if store.orders.isEmpty { await store.load() } }
        .sheet(isPresented: $showDatePicker) {
            DateRangeSheet(
                from: OrderFmt.parseApiDate(store.dateFrom) ?? Date(),
                to: OrderFmt.parseApiDate(store.dateTo) ?? Date()
            ) { from, to in store.setDateRange(from: from, to: to) }
        }
    }

    // MARK: - Filter bar (search + distributor + date range)

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                    TextField("Search by order ID, distributor or product…", text: $searchText)
                        .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                        .onChange(of: searchText) { _ in debounceSearch() }
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                distributorMenu
            }
            dateRangePill
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
        .background(Brand.surface)
    }

    private var distributorMenu: some View {
        Menu {
            Button("All Distributors") { store.setDistributor(nil) }
            ForEach(store.knownDistributors) { d in
                Button(d.name) { store.setDistributor(d) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(store.distributorName ?? "All Distributors")
                    .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            }
            .padding(.horizontal, 12).frame(height: 44).frame(maxWidth: 150)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var dateRangePill: some View {
        Button { showDatePicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Text("\(OrderFmt.display(store.dateFrom))  →  \(OrderFmt.display(store.dateTo))")
                    .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12).frame(height: 44)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var statusTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(statusKeys.enumerated()), id: \.offset) { idx, key in
                    FilterChip(label: "\(statusTitles[idx])  \(store.count(for: key))",
                               selected: key == store.status) { store.setStatus(key) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Brand.surface)
    }

    // MARK: - Content

    // Lives inside the body's ScrollView, so it lays rows out directly rather than
    // opening a second, nested scroll view.
    @ViewBuilder
    private var content: some View {
        if store.loading && store.orders.isEmpty {
            ProgressView().padding(.top, 60)
        } else if store.orders.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.orders) { order in
                    NavigationLink(value: order) { OrderRow(order: order) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox").font(.system(size: 50)).foregroundColor(Brand.textTertiary)
            Text("No orders found.").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Brand.background)
    }

    @ViewBuilder
    private var paginationBar: some View {
        if let p = store.pagination, p.total > 0 {
            HStack {
                Text(paginationLabel(p)).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Spacer()
                if p.total_pages > 1 {
                    Button { store.prevPage() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(store.page <= 1).opacity(store.page <= 1 ? 0.4 : 1)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))

                    Button { store.nextPage() } label: {
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(store.page >= p.total_pages).opacity(store.page >= p.total_pages ? 0.4 : 1)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                }
            }
            .foregroundColor(Brand.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Brand.surface)
        }
    }

    private func paginationLabel(_ p: PaginationDTO) -> String {
        let from = (p.page - 1) * p.per_page + 1
        let to = min(p.page * p.per_page, p.total)
        return "Showing \(from) to \(to) of \(p.total) orders"
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            store.search = searchText
            store.reload()
        }
    }
}

// MARK: - Status helpers (shared with OrderDetailView)

func statusLabel(_ key: String) -> String {
    key.split(separator: "_").map { $0.prefix(1).uppercased() + String($0.dropFirst()) }.joined(separator: " ")
}

func statusColor(_ key: String) -> Color {
    switch key {
    case "pending":          return Color(hex: "#D97706")
    case "accepted":         return Brand.purple
    case "picking":          return Color(hex: "#2563EB")
    case "packing":          return Color(hex: "#0891B2")
    case "out_for_delivery": return Color(hex: "#EA580C")
    case "delivered":        return Brand.success
    case "cancelled":        return Brand.danger
    case "failed":           return Brand.danger
    default:                 return Color(hex: "#64748B")
    }
}

// MARK: - Order card

struct OrderRow: View {
    let order: OrderDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                InitialBadge(text: OrderLogo.initials(order.distributorName),
                             color: OrderLogo.color(order.distributor_id), size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.distributorName).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.purple)
                    Text(order.order_number).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    Text(OrderFmt.createdAt(order.created_at)).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(OrderFmt.money(order.amount)).font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
                    StatusBadge(text: statusLabel(order.statusKey),
                                fg: statusColor(order.statusKey), bg: statusColor(order.statusKey).opacity(0.14))
                }
            }

            Text("PRODUCTS \(order.products?.count ?? 0)")
                .font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundColor(Brand.textSecondary)
                .padding(.top, 12)

            WrappingTextChips(items: order.products ?? []).padding(.top, 6)

            Divider().padding(.top, 12)

            HStack {
                Text(deliveryInfo).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "eye").font(.system(size: 12))
                    Text("View Detail").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Brand.purple)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Brand.purple, lineWidth: 1))
            }
            .padding(.top, 12)
        }
        .card()
        // Highlight the card border for pending orders (mirrors the web portal).
        .overlay {
            if order.statusKey == "pending" {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(statusColor("pending"), lineWidth: 1.0)
            }
        }
    }

    private var deliveryInfo: String {
        let date = OrderFmt.deliveryDate(order.delivery_date)
        guard !date.isEmpty else { return "" }
        return (order.statusKey == "delivered" ? "Delivered " : "Est. delivery ") + date
    }
}
