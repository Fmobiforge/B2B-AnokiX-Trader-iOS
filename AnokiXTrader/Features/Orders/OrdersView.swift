import SwiftUI

struct OrdersView: View {
    @State private var filter = "All Orders"

    private var orders: [OrderItem] {
        filter == "All Orders" ? MockData.orders
            : MockData.orders.filter { statusLabel($0.status).caseInsensitiveCompare(filter) == .orderedSame }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Orders", subtitle: "Stock you ordered from distributors")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MockData.statusFilters, id: \.self) { f in
                        FilterChip(label: f, selected: f == filter) { filter = f }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Brand.surface)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(orders) { order in
                        NavigationLink(value: order) { OrderCard(order: order) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
        }
        .navigationBarHidden(true)
        .navigationDestination(for: OrderItem.self) { OrderDetailView(order: $0) }
    }
}

func statusLabel(_ key: String) -> String {
    switch key {
    case "pending": return "Pending"
    case "accepted": return "Accepted"
    case "picking": return "Picking"
    case "packing": return "Packing"
    case "out_for_delivery": return "Out for Delivery"
    case "delivered": return "Delivered"
    case "cancelled": return "Cancelled"
    default: return key.capitalized
    }
}

func statusColor(_ key: String) -> Color {
    switch key {
    case "pending": return Brand.warning
    case "accepted", "picking", "packing": return Brand.info
    case "out_for_delivery": return Brand.warning
    case "delivered": return Brand.success
    case "cancelled": return Brand.danger
    default: return Brand.purple
    }
}

struct OrderCard: View {
    let order: OrderItem

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                InitialBadge(text: order.initials, color: Color(hex: order.logoColor), size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.traderName).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Text(order.subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                StatusBadge(text: statusLabel(order.status),
                            fg: statusColor(order.status), bg: statusColor(order.status).opacity(0.14))
            }
            HStack {
                Text("\(order.orderId) · \(order.time)").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Spacer()
            }
            Divider()
            HStack {
                Text("\(order.itemsCount) items").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text(order.amount).font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
            HStack {
                Image(systemName: "shippingbox").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Text(order.deliveryInfo).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text(order.actionLabel).font(.system(size: 13, weight: .semibold)).foregroundColor(statusColor(order.status))
            }
        }
        .card()
    }
}
