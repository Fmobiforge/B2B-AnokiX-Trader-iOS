import SwiftUI

/// Trader inventory dashboard (live, GET api/trader/inventory): KPI summary, status
/// breakdown, fast movers, recent stock-movement ledger, and a filterable product
/// list. Tapping a product opens a sheet to adjust stock (signed qty + reason) and
/// jump to its Stock History. The toolbar opens Inventory Analytics.
struct InventoryView: View {
    @EnvironmentObject var router: Router
    @StateObject private var store = InventoryStore()
    @State private var sheet: InventorySheet?
    @State private var toastMsg: String?
    @State private var showAdjustPicker = false

    private let statCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let filters: [(key: String, label: String)] = [
        ("all", "All"), ("fast", "Fast Moving"), ("slow", "Slow Moving"),
        ("in_stock", "In Stock"), ("low_stock", "Low Stock"), ("out_of_stock", "Out of Stock")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statStrip
                actionButtons
                if !store.chart.isEmpty { statusCard }
                if !store.fastMoving.isEmpty { fastMovingCard }
                if !store.movements.isEmpty { movementsCard }
                productsSection
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if store.rows.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        .confirmationDialog("Adjust which product?", isPresented: $showAdjustPicker, titleVisibility: .visible) {
            ForEach(store.rows) { row in
                Button(row.name ?? "—") { sheet = .adjust(row) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .analytics } label: { Image(systemName: "chart.bar.xaxis") }
            }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .adjust(let row):
                AdjustStockSheet(row: row, store: store,
                                 onHistory: { sheet = .history(row) },
                                 onDone: { msg in sheet = nil; if let msg { toastMsg = msg } })
                    .presentationDetents([.large])
            case .history(let row):
                NavigationStack { StockHistoryView(productId: row.id, title: row.name ?? "Product") }
            case .analytics:
                NavigationStack { InventoryAnalyticsView() }
            }
        }
        .toast($toastMsg)
    }

    private var statStrip: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: statCols, spacing: 12) {
                StatTile(label: "Stock Value", value: InvFmt.money(store.summary?.total_stock_value ?? 0), icon: "banknote.fill", iconTint: Brand.info)
                StatTile(label: "Total Units", value: "\(store.summary?.total_units ?? 0)", icon: "shippingbox.fill", iconTint: Brand.purple)
                StatTile(label: "Low Stock", value: "\(store.summary?.low_stock ?? 0)", valueColor: Brand.warning, icon: "exclamationmark.triangle.fill", iconTint: Brand.warning)
                StatTile(label: "Out of Stock", value: "\(store.summary?.out_of_stock ?? 0)", valueColor: Brand.danger, icon: "xmark.octagon.fill", iconTint: Brand.danger)
            }
            StatTile(label: "Stock Movement", value: "\(store.summary?.stock_movement ?? 0)", icon: "arrow.left.arrow.right", iconTint: Brand.purple)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { showAdjustPicker = true } label: {
                Label("Adjust Stock", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            Button { router.presented = .goodsReturns } label: {
                Label("Return Stock (GRN)", systemImage: "arrowshape.turn.up.left")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var statusCard: some View {
        let total = max(store.chart.reduce(0) { $0 + ($1.value ?? 0) }, 0)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Inventory Summary")
            ZStack {
                if total <= 0 {
                    Circle().stroke(Brand.divider, lineWidth: 22)
                } else {
                    ForEach(Array(ringArcs(total: total).enumerated()), id: \.offset) { _, arc in
                        Circle().trim(from: arc.start, to: arc.end)
                            .stroke(arc.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }
                }
                VStack(spacing: 1) {
                    Text("\(store.summary?.total_products ?? 0)").font(.system(size: 22, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Text("Products").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                }
            }
            .frame(width: 150, height: 150)
            .frame(maxWidth: .infinity)
            VStack(spacing: 6) {
                ForEach(Array(store.chart.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: s.color ?? "#E2E8F0")).frame(width: 10, height: 10)
                        Text(s.type ?? "").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        Spacer()
                        Text(String(format: "%.0f%%", s.value ?? 0)).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    }
                }
            }
        }
        .card()
    }

    /// Cumulative ring arcs (fractions of the circle) for the status slices.
    private func ringArcs(total: Double) -> [(start: CGFloat, end: CGFloat, color: Color)] {
        var cursor: CGFloat = 0
        return store.chart.map { s in
            let frac = CGFloat((s.value ?? 0) / total)
            let arc = (start: cursor, end: cursor + frac, color: Color(hex: s.color ?? "#E2E8F0"))
            cursor += frac
            return arc
        }
    }

    private var fastMovingCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Top Fast Moving Products")
            ForEach(store.fastMoving) { m in
                HStack(spacing: 12) {
                    Text("\(m.rank ?? 0)")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(Brand.purple)
                        .frame(width: 26, height: 26).background(Brand.purpleLight).clipShape(Circle())
                    Text(m.name ?? "—").font(.system(size: 13)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    Spacer()
                    Text("\(m.units ?? 0) units").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                }
                .padding(.vertical, 8)
            }
        }
        .card()
    }

    private var movementsCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Recent Stock Movements")
            ForEach(store.movements.prefix(6)) { m in
                MovementRow(m: m, showProduct: true)
            }
        }
        .card()
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Products").font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.key) { f in
                        FilterChip(label: f.label, selected: f.key == store.filter) { store.filter = f.key }
                    }
                }
            }
            if store.loading && store.rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
            } else if store.filteredRows.isEmpty {
                Text("No products match this filter.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity).padding(.top, 24)
            } else {
                ForEach(store.filteredRows) { row in
                    InventoryRowCard(row: row).onTapGesture { sheet = .adjust(row) }
                }
            }
        }
    }
}

enum InventorySheet: Identifiable {
    case adjust(InvRow), history(InvRow), analytics
    var id: String {
        switch self {
        case .adjust(let r):  return "adjust-\(r.id)"
        case .history(let r): return "history-\(r.id)"
        case .analytics:      return "analytics"
        }
    }
}

// MARK: - Product card

private struct InventoryRowCard: View {
    let row: InvRow
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                InitialBadge(text: String((row.name ?? "?").prefix(1)), color: Color(hex: row.imageColor ?? "#7C3AED"), size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name ?? "—").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    Text(row.sku ?? "").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                StatusBadge(text: row.statusLabel, fg: row.statusTone.fg, bg: row.statusTone.bg)
            }
            Text("\(row.category ?? "") · \(row.warehouse ?? "") · \(row.updatedAt ?? "")")
                .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            ProgressView(value: row.stockPercent, total: 100).tint(Color(hex: row.imageColor ?? "#7C3AED"))
            HStack {
                Text("\(row.onHand) / \(row.capacity ?? 0) units").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Text(InvFmt.money(row.value)).font(.system(size: 13, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
        }
        .card()
    }
}

// MARK: - Movement ledger row (shared dashboard + history)

struct MovementRow: View {
    let m: InvMovement
    var showProduct: Bool = true

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                Text(sub).font(.system(size: 11)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(qtyText).font(.system(size: 13, weight: .bold)).foregroundColor(qtyColor)
                Text("Bal \(m.balance_after ?? 0)").font(.system(size: 11)).foregroundColor(Brand.textTertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private var ref: String { m.reference_number ?? "" }
    private var title: String {
        showProduct ? (m.product_name ?? "—") : (ref.isEmpty ? InvFmt.movementTypeLabel(m.movement_type) : ref)
    }
    private var sub: String {
        let lead = showProduct
            ? (InvFmt.movementTypeLabel(m.movement_type) + (ref.isEmpty ? "" : " · \(ref)"))
            : (m.note?.isEmpty == false ? m.note! : InvFmt.movementTypeLabel(m.movement_type))
        return lead + " · " + InvFmt.dateTime(m.created_at)
    }
    private var qtyText: String { m.net > 0 ? "+\(m.net)" : "\(m.net)" }
    private var qtyColor: Color { m.net > 0 ? Brand.success : (m.net < 0 ? Brand.danger : Brand.textSecondary) }
}

// MARK: - Adjust Stock sheet

private struct AdjustStockSheet: View {
    let row: InvRow
    @ObservedObject var store: InventoryStore
    let onHistory: () -> Void
    let onDone: (String?) -> Void

    @State private var isAdd = true
    @State private var amount = 1
    @State private var reasonKey = InvAdjustReason.keys[0]
    @State private var submitting = false
    @State private var errorMsg: String?

    private var signed: Int { isAdd ? amount : -amount }
    private var newOnHand: Int { max(0, row.onHand + signed) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name ?? "—").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Text(row.sku ?? "").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                StatusBadge(text: row.statusLabel, fg: row.statusTone.fg, bg: row.statusTone.bg)
                Button { onDone(nil) } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textSecondary)
                }
                .padding(.leading, 8)
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("On hand: \(row.onHand) · Value \(InvFmt.money(row.value))")
                            .font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                        Text("\(row.brand ?? "") · \(row.category ?? "") · \(row.warehouse ?? "")")
                            .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    }

                    Button(action: onHistory) {
                        Label("View Stock History", systemImage: "clock")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Brand.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Text("Adjust Stock").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Picker("", selection: $isAdd) {
                        Text("Add (+)").tag(true)
                        Text("Remove (−)").tag(false)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Quantity").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        Spacer()
                        HStack(spacing: 0) {
                            Button { amount = max(1, amount - 1) } label: { Image(systemName: "minus").frame(width: 36, height: 36) }
                                .buttonStyle(.plain)
                            Text("\(amount)").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary).frame(minWidth: 40)
                            Button { amount += 1 } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
                                .buttonStyle(.plain)
                        }
                        .foregroundColor(Brand.purple)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                    }

                    Menu {
                        ForEach(Array(InvAdjustReason.keys.enumerated()), id: \.offset) { idx, key in
                            Button(InvAdjustReason.labels[idx]) { reasonKey = key }
                        }
                    } label: {
                        HStack {
                            Text("Reason: \(InvAdjustReason.label(reasonKey))").foregroundColor(Brand.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        }
                        .font(.system(size: 14))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                    }

                    Text("New on hand: \(newOnHand)").font(.system(size: 13)).foregroundColor(Brand.textSecondary)

                    if let errorMsg {
                        Text(errorMsg).font(.system(size: 12, weight: .medium)).foregroundColor(Brand.danger)
                    }
                }
                .padding(16)
            }

            Button(action: apply) {
                HStack(spacing: 8) {
                    if submitting { ProgressView().tint(.white) }
                    Text(submitting ? "Applying…" : "Apply Adjustment")
                }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Brand.purple.opacity(submitting ? 0.7 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(submitting)
            .padding(16)
            .background(Brand.surface)
            .overlay(Divider(), alignment: .top)
        }
        .background(Brand.surface)
    }

    private func apply() {
        submitting = true
        errorMsg = nil
        Task {
            do {
                try await store.adjust(productId: row.id, quantity: signed, reason: reasonKey)
                submitting = false
                onDone("Stock adjusted.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription ?? "Failed to adjust stock."
            }
        }
    }
}

// MARK: - Stock History

struct StockHistoryView: View {
    let productId: Int
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var data: InventoryHistoryData?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let d = data {
                    snapshot(d)
                    ledger(d)
                } else if loading {
                    ProgressView().padding(.top, 60)
                } else {
                    Text(error ?? "No history.").font(.system(size: 13)).foregroundColor(Brand.textSecondary).padding(.top, 60)
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
        .task { await load() }
    }

    private func snapshot(_ d: InventoryHistoryData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SKU: \(d.product?.sku ?? "—")").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Spacer()
                let tone = InvFmt.statusTone(d.status)
                StatusBadge(text: InvFmt.statusLabel(d.status), fg: tone.fg, bg: tone.bg)
            }
            kv("On hand", "\(d.on_hand ?? 0) units")
            kv("Stock value", InvFmt.money(d.stock_value ?? 0))
            kv("Average cost", InvFmt.money(d.average_cost ?? 0))
            kv("Low-stock at", "\(d.low_stock_threshold ?? 0)")
            kv("Updated", InvFmt.dateTime(d.updated_at))
        }
        .card()
    }

    private func ledger(_ d: InventoryHistoryData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Movement Ledger")
            let moves = d.movements ?? []
            if moves.isEmpty {
                Text("No movements recorded yet.").font(.system(size: 12)).foregroundColor(Brand.textSecondary).padding(.vertical, 6)
            } else {
                ForEach(moves) { m in MovementRow(m: m, showProduct: false) }
            }
        }
        .card()
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
        }
    }

    private func load() async {
        loading = true
        do {
            data = try await APIClient.shared.getInventoryHistory(productId: productId)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load history."
        }
        loading = false
    }
}

// MARK: - Inventory Analytics

struct InventoryAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var data: InventoryAnalyticsData?
    @State private var loading = true
    @State private var error: String?

    private let ageLabels = ["0–30 days", "31–60 days", "61–90 days", "90+ days"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let d = data {
                    grossProfit(d)
                    ageingCard(d)
                    reorderCard(d)
                } else if loading {
                    ProgressView().padding(.top, 60)
                } else {
                    Text(error ?? "No analytics.").font(.system(size: 13)).foregroundColor(Brand.textSecondary).padding(.top, 60)
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Inventory Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
        .task { await load() }
    }

    private func grossProfit(_ d: InventoryAnalyticsData) -> some View {
        let gp = d.gross_profit
        return VStack(alignment: .leading, spacing: 10) {
            Text("Gross Profit · Last \(d.window_days ?? 30) days").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            HStack {
                Text(InvFmt.money(gp?.gross_profit ?? 0)).font(.system(size: 24, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Text(String(format: "%.1f%% margin", gp?.margin_pct ?? 0))
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.success)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Brand.successBg).clipShape(Capsule())
            }
            Divider()
            kv("Net revenue (ex-VAT)", InvFmt.money(gp?.net_revenue ?? 0))
            kv("Cost of goods sold", InvFmt.money(gp?.cogs ?? 0))
            kv("Units sold", "\(gp?.units_sold ?? 0)")
        }
        .card()
    }

    private func ageingCard(_ d: InventoryAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Stock Ageing")
            ForEach(Array((d.ageing ?? []).enumerated()), id: \.offset) { idx, b in
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: b.color ?? "#E2E8F0")).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(idx < ageLabels.count ? ageLabels[idx] : (b.label ?? ""))
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        Text("\(b.products ?? 0) products · \(b.units ?? 0) units")
                            .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                    }
                    Spacer()
                    Text(InvFmt.money(b.value ?? 0)).font(.system(size: 13, weight: .bold)).foregroundColor(Brand.textPrimary)
                }
                .padding(.vertical, 8)
            }
        }
        .card()
    }

    private func reorderCard(_ d: InventoryAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Reorder Suggestions")
            let list = d.reorder ?? []
            if list.isEmpty {
                Text("Nothing needs reordering right now.").font(.system(size: 12)).foregroundColor(Brand.textSecondary).padding(.vertical, 6)
            } else {
                ForEach(list) { r in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.name ?? "—").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                            Text("\(r.sku ?? "") · On hand \(r.on_hand ?? 0) / \(r.threshold ?? 0) · sold \(r.sold_last_30 ?? 0)")
                                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Order \(r.suggested ?? 0)").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.purple)
                            let tone = urgencyTone(r.urgency)
                            Text((r.urgency ?? "—").capitalized)
                                .font(.system(size: 9, weight: .semibold)).foregroundColor(tone.fg)
                                .padding(.horizontal, 8).padding(.vertical, 2).background(tone.bg).clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .card()
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
        }
    }

    private func urgencyTone(_ urgency: String?) -> (fg: Color, bg: Color) {
        switch urgency ?? "" {
        case "high":   return (Brand.danger, Brand.dangerBg)
        case "medium": return (Brand.warning, Brand.warningBg)
        default:       return (Brand.success, Brand.successBg)
        }
    }

    private func load() async {
        loading = true
        do {
            data = try await APIClient.shared.getInventoryAnalytics(days: 30)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load analytics."
        }
        loading = false
    }
}
