import SwiftUI

struct InventoryView: View {
    @State private var items = MockData.inventory
    @State private var filter = "All Inventory"
    @State private var selected: InventoryItem?

    private let statCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var totalValue: Double { items.reduce(0) { $0 + $1.stockValue } }
    private var totalUnits: Int { items.reduce(0) { $0 + $1.units } }
    private var lowCount: Int { items.filter { $0.statusKey == "low_stock" }.count }
    private var outCount: Int { items.filter { $0.statusKey == "out_of_stock" }.count }

    private var filtered: [InventoryItem] {
        switch filter {
        case "Fast Moving": return items.filter { $0.movement == "fast" }
        case "Slow Moving": return items.filter { $0.movement == "slow" }
        case "Low Stock": return items.filter { $0.statusKey == "low_stock" }
        case "Out of Stock": return items.filter { $0.statusKey == "out_of_stock" }
        case "Damaged": return items.filter { $0.statusKey == "damaged" }
        case "Expired": return items.filter { $0.statusKey == "expired" }
        default: return items
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: statCols, spacing: 12) {
                    StatTile(label: "Total Stock Value", value: Money.rand(totalValue), valueColor: Brand.textPrimary, icon: "banknote", iconTint: Brand.success)
                    StatTile(label: "Total Units", value: "\(totalUnits)", icon: "shippingbox", iconTint: Brand.purple)
                    StatTile(label: "Low Stock", value: "\(lowCount)", valueColor: Brand.warning, icon: "exclamationmark.triangle", iconTint: Brand.warning)
                    StatTile(label: "Out of Stock", value: "\(outCount)", valueColor: Brand.danger, icon: "xmark.octagon", iconTint: Brand.danger)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MockData.inventoryFilters, id: \.self) { f in
                            FilterChip(label: f, selected: f == filter) { filter = f }
                        }
                    }
                }

                VStack(spacing: 12) {
                    ForEach(filtered) { item in
                        InventoryCard(item: item).onTapGesture { selected = item }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .sheet(item: $selected) { item in
            InventoryDetailSheet(item: item) { newUnits in
                if let idx = items.firstIndex(of: item) { items[idx].units = newUnits }
            }
            .presentationDetents([.medium])
        }
    }
}

struct InventoryCard: View {
    let item: InventoryItem
    private var tone: (fg: Color, bg: Color) { badgeTone(item.status) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                InitialBadge(text: String(item.name.prefix(1)), color: Color(hex: item.imageColor), size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    Text(item.sku).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                StatusBadge(text: item.status, fg: tone.fg, bg: tone.bg)
            }
            Text("\(item.category) · \(item.warehouse) · \(item.updatedAt)")
                .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: Double(item.stockPercent), total: 100).tint(Color(hex: item.imageColor))
            HStack {
                Text("\(item.units) units").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Text(Money.rand(item.stockValue)).font(.system(size: 13, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
        }
        .card()
    }
}

struct InventoryDetailSheet: View {
    let item: InventoryItem
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var units: Int

    init(item: InventoryItem, onSave: @escaping (Int) -> Void) {
        self.item = item; self.onSave = onSave
        _units = State(initialValue: item.units)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                InitialBadge(text: String(item.name.prefix(1)), color: Color(hex: item.imageColor), size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 17, weight: .bold))
                    Text(item.sku).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
            }
            VStack(spacing: 8) {
                infoRow("Brand", item.brand); infoRow("Category", item.category)
                infoRow("Warehouse", item.warehouse); infoRow("Barcode", item.barcode)
                infoRow("Stock Value", Money.rand(item.stockValue))
            }
            HStack {
                Text("Adjust units on hand").font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 16) {
                    Button { units = max(0, units - 1) } label: { Image(systemName: "minus.circle.fill").foregroundColor(Brand.textTertiary).font(.title2) }
                    Text("\(units)").font(.system(size: 17, weight: .bold)).frame(minWidth: 40)
                    Button { units += 1 } label: { Image(systemName: "plus.circle.fill").foregroundColor(Brand.purple).font(.title2) }
                }
            }
            Spacer()
            Button("Save Adjustment") { onSave(units); dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Brand.background)
    }

    private func infoRow(_ l: String, _ r: String) -> some View {
        HStack { Text(l).foregroundColor(Brand.textSecondary); Spacer(); Text(r).fontWeight(.medium) }
            .font(.system(size: 13))
    }
}
