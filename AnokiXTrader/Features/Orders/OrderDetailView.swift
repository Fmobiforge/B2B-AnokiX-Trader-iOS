import SwiftUI

/// Order detail / tracking (mirrors Orders2/Orders3.png). Renders the header from
/// the order summary immediately, then fetches the full order (with items) from
/// GET /api/trader/orders?id=.
struct OrderDetailView: View {
    let order: OrderDTO
    @State private var detail: OrderDTO?
    @State private var loading = true

    private let stageKeys = ["pending", "accepted", "picking", "packing", "out_for_delivery", "delivered"]
    private let stageLabels = ["Order Placed", "Accepted by Distributor", "Picking", "Packing",
                               "Out for Delivery", "Delivered"]

    /// Full order once fetched, otherwise the summary passed in.
    private var o: OrderDTO { detail ?? order }
    private var currentIndex: Int { stageKeys.firstIndex(of: o.statusKey) ?? 0 }
    private var cancelled: Bool { o.statusKey == "cancelled" }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                trackingCard
                addressCard
                itemsCard
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetch() }
    }

    private func fetch() async {
        detail = try? await APIClient.shared.getOrder(id: String(order.id))
        loading = false
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            InitialBadge(text: OrderLogo.initials(o.distributorName),
                         color: OrderLogo.color(o.distributor_id), size: 50)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(o.order_number).font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
                    StatusBadge(text: statusLabel(o.statusKey),
                                fg: statusColor(o.statusKey), bg: statusColor(o.statusKey).opacity(0.14))
                }
                Text(o.distributorName).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(OrderFmt.money(o.amount)).font(.system(size: 16, weight: .bold)).foregroundColor(Brand.purple)
                Text("\(o.item_count ?? o.items?.count ?? 0) items")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
        }
        .card()
    }

    // MARK: - Tracking timeline

    private var trackingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Order Tracking").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
                Circle().fill(Brand.success).frame(width: 6, height: 6)
                Text("Live updates").font(.system(size: 12)).foregroundColor(Brand.success)
                Spacer()
            }
            if cancelled {
                Text("This order was cancelled.").font(.system(size: 13)).foregroundColor(Brand.danger)
            }
            ForEach(Array(stageLabels.enumerated()), id: \.offset) { idx, label in
                timelineRow(idx: idx, label: label)
            }
        }
        .card()
    }

    private func timelineRow(idx: Int, label: String) -> some View {
        let done = !cancelled && idx < currentIndex
        let current = !cancelled && idx == currentIndex
        let terminalDone = current && o.statusKey == "delivered"
        let reached = done || current
        let isLast = idx == stageLabels.count - 1

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                stageCircle(done: done || terminalDone, current: current && !terminalDone)
                if !isLast {
                    Rectangle().fill(done ? Brand.success : Brand.border).frame(width: 2, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: current ? .bold : .medium))
                    .foregroundColor(reached ? Brand.textPrimary : Brand.textTertiary)
                if let sub = stageSubtitle(idx) {
                    Text(sub).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
            }
            .padding(.top, 1)
            Spacer()
        }
    }

    @ViewBuilder
    private func stageCircle(done: Bool, current: Bool) -> some View {
        if done {
            Circle().fill(Brand.success).frame(width: 24, height: 24)
                .overlay(Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
        } else {
            Circle().fill(Color.white).frame(width: 24, height: 24)
                .overlay(Circle().stroke(current ? Brand.purple : Brand.border, lineWidth: current ? 3 : 2))
        }
    }

    private func stageSubtitle(_ idx: Int) -> String? {
        switch idx {
        case 0:
            let d = OrderFmt.createdAt(o.created_at)
            return d.isEmpty ? nil : d
        case 4:
            let date = OrderFmt.deliveryDate(o.delivery_date)
            guard !date.isEmpty else { return nil }
            let window = OrderFmt.timeWindow(o.delivery_start_time, o.delivery_end_time)
            return "Est. \(date)" + (window.isEmpty ? "" : ", \(window)")
        case 5:
            let date = OrderFmt.deliveryDate(o.delivery_date)
            return date.isEmpty ? nil : "Est. \(date)"
        default:
            return nil
        }
    }

    // MARK: - Delivery address

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 15)).foregroundColor(Brand.purple)
                Text("Delivery Address").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
            if let business = o.delivery_address?.business, !business.isEmpty {
                Text(business).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.purple)
            }
            Text(o.delivery_address?.address ?? "—").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            if let notes = o.notes, !notes.isEmpty {
                Text("Note: \(notes)").font(.system(size: 12)).foregroundColor(Brand.textSecondary).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Items

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items (\(o.items?.count ?? 0))").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
            if loading && o.items == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                ForEach(o.items ?? []) { item in
                    OrderItemRow(item: item)
                    if item.id != o.items?.last?.id { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct OrderItemRow: View {
    let item: OrderItemDTO

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: item.product?.image_url)
                .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    Text("x\(item.quantity)")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(4)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.product?.name ?? "").font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Brand.textPrimary).lineLimit(2)
                Text("\(item.quantity) × \(OrderFmt.money(item.unit_price ?? 0))")
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
            Text(OrderFmt.money(item.line_total ?? 0)).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Date range picker sheet

struct DateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var from: Date
    @State private var to: Date
    let onApply: (Date, Date) -> Void

    init(from: Date, to: Date, onApply: @escaping (Date, Date) -> Void) {
        _from = State(initialValue: from)
        _to = State(initialValue: to)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker("From", selection: $from, displayedComponents: .date)
                DatePicker("To", selection: $to, in: from..., displayedComponents: .date)
                Spacer()
                Button("Apply") {
                    onApply(from, to)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
