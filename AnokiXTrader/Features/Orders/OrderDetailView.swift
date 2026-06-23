import SwiftUI

struct OrderDetailView: View {
    let order: OrderItem

    private let stages = ["pending", "accepted", "picking", "packing", "out_for_delivery", "delivered"]
    private let stageLabels = ["Order Placed", "Accepted", "Picking", "Packing", "Out for Delivery", "Delivered"]

    private var currentIndex: Int { stages.firstIndex(of: order.status) ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        InitialBadge(text: order.initials, color: Color(hex: order.logoColor), size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(order.traderName).font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                            Text(order.subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                    }
                    Divider()
                    detailRow("Order ID", order.orderId)
                    detailRow("Placed", order.time)
                    detailRow("Items", "\(order.itemsCount)")
                    detailRow("Total", order.amount, valueColor: Brand.purple, bold: true)
                }
                .card()

                // Tracking timeline
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Order Tracking").padding(.bottom, 8)
                    ForEach(Array(stageLabels.enumerated()), id: \.offset) { idx, label in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(idx <= currentIndex ? Brand.purple : Brand.border)
                                    .frame(width: 16, height: 16)
                                    .overlay(idx <= currentIndex ? Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white) : nil)
                                if idx < stageLabels.count - 1 {
                                    Rectangle().fill(idx < currentIndex ? Brand.purple : Brand.border)
                                        .frame(width: 2, height: 34)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .font(.system(size: 14, weight: idx == currentIndex ? .bold : .medium))
                                    .foregroundColor(idx <= currentIndex ? Brand.textPrimary : Brand.textTertiary)
                                if idx == currentIndex {
                                    Text(order.deliveryInfo).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                }
                            }
                            .padding(.top, -2)
                            Spacer()
                        }
                    }
                }
                .card()

                Button(order.actionLabel) {}.buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ l: String, _ r: String, valueColor: Color = Brand.textPrimary, bold: Bool = false) -> some View {
        HStack {
            Text(l).font(.system(size: 14)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(r).font(.system(size: 14, weight: bold ? .bold : .semibold)).foregroundColor(valueColor)
        }
    }
}
