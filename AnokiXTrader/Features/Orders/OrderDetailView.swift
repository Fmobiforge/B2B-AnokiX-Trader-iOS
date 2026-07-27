import SwiftUI

/// Order detail / tracking (mirrors Orders2/Orders3.png). Renders the header from
/// the order summary immediately, then fetches the full order (with items) from
/// GET /api/trader/orders?id=.
struct OrderDetailView: View {
    let order: OrderDTO
    @State private var detail: OrderDTO?
    @State private var loading = true
    @State private var pdfDoc: PDFDoc?
    @State private var toastMsg: String?

    private let stageKeys = ["pending", "accepted", "picking", "packing", "out_for_delivery", "delivered"]
    private let stageLabels = ["Order Placed", "Accepted by Distributor", "Picking", "Packing",
                               "Out for Delivery", "Delivered"]

    /// Full order once fetched, otherwise the summary passed in.
    private var o: OrderDTO { detail ?? order }
    private var currentIndex: Int { stageKeys.firstIndex(of: o.statusKey) ?? 0 }
    private var cancelled: Bool { o.statusKey == "cancelled" }

    /// Total ordered units shown in the header ("3 items"). The detail endpoint
    /// carries no `item_count`, so it is summed from the items' quantities; the
    /// list endpoint's `item_count` is the fallback before items load.
    private var itemUnitCount: Int {
        if let items = o.items, !items.isEmpty { return items.reduce(0) { $0 + $1.quantity } }
        return o.item_count ?? 0
    }

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
        .sheet(item: $pdfDoc) { doc in GrvPdfView(doc: doc) }
        .toast($toastMsg)
    }

    private func fetch() async {
        detail = try? await APIClient.shared.getOrder(id: String(order.id))
        loading = false
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
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
                    Text("\(itemUnitCount) items")
                        .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
            }
            HStack {
                Spacer()
                Button { openPdf() } label: {
                    Label("Purchase Order PDF", systemImage: "doc.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func openPdf() {
        toastMsg = "Generating PDF…"
        Task {
            do {
                let pdf = try await APIClient.shared.getOrderPdf(id: String(o.id))
                guard let b64 = pdf.data,
                      let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else {
                    toastMsg = "PDF unavailable."
                    return
                }
                let name = (pdf.filename?.isEmpty == false) ? pdf.filename! : "\(o.order_number).pdf"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try bytes.write(to: url)
                toastMsg = nil
                pdfDoc = PDFDoc(url: url, title: o.order_number)
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription ?? "Couldn't open PDF."
            }
        }
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

/// Loads an order by id then shows `OrderDetailView`. Used for deep links that only
/// carry an order id (e.g. tapping an order notification).
struct OrderDetailLoader: View {
    let orderId: Int
    @State private var order: OrderDTO?
    @State private var failed = false

    var body: some View {
        Group {
            if let order {
                OrderDetailView(order: order)
            } else if failed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 34)).foregroundColor(Brand.textTertiary)
                    Text("Couldn't load this order.").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Brand.background)
                .navigationTitle("Order Details")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.background)
                    .navigationTitle("Order Details")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            do { order = try await APIClient.shared.getOrder(id: String(orderId)) }
            catch { failed = true }
        }
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
        // Self-styled sheet (custom header, no NavigationStack) drawn on an explicit
        // opaque Brand background + forced light scheme — matching SelectOptionsSheet /
        // the app's other pickers. Without this the sheet inherited a clear backing and
        // its contents (incl. the DatePicker's calendar popover) showed through onto the
        // screen behind it.
        VStack(spacing: 0) {
            HStack {
                Text("Date range")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Brand.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                dateRow("From", selection: $from, range: nil)
                Divider()
                dateRow("To", selection: $to, range: from...)
            }
            .padding(.horizontal, 4)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .tint(Brand.purple)

            Spacer(minLength: 0)

            Button("Apply") {
                onApply(from, to)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.background.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func dateRow(_ label: String, selection: Binding<Date>, range: PartialRangeFrom<Date>?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Brand.textPrimary)
            Spacer()
            if let range {
                DatePicker("", selection: selection, in: range, displayedComponents: .date).labelsHidden()
            } else {
                DatePicker("", selection: selection, displayedComponents: .date).labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
