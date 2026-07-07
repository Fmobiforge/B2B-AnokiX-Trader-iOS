import SwiftUI

/// The committed result of the Filters sheet, applied back onto `CategoryProductsStore`.
struct CategoryFilterResult {
    var brands: Set<Int>
    var subCategories: Set<Int>
    var packSizes: Set<String>
    var onPromotion: Bool
    var inStock: Bool
    var minPrice: Double?
    var maxPrice: Double?
}

/// Filters sheet — iOS counterpart of the Android `sheet_category_filters.xml` +
/// `showFilterSheet()`. All options come from the category API `filters` facets (live
/// counts). Edits happen on working copies and only commit on Apply. Price-range bounds
/// are data-driven from `filters.price_range`; the max thumb at the ceiling means "and
/// above" (label shows "+", and no max_price is sent — computed in `apply()`).
struct CategoryFilterSheet: View {
    let filters: CategoryFiltersDTO?
    let currency: String
    let onApply: (CategoryFilterResult) -> Void

    @Environment(\.dismiss) private var dismiss

    // Working copies.
    @State private var wBrands: Set<Int>
    @State private var wSubs: Set<Int>
    @State private var wPacks: Set<String>
    @State private var wPromo: Bool
    @State private var wStock: Bool
    @State private var lo: Double
    @State private var hi: Double

    private let rangeMin: Double
    private let rangeMax: Double

    init(filters: CategoryFiltersDTO?, currency: String,
         selBrands: Set<Int>, selSubCategories: Set<Int>, selPackSizes: Set<String>,
         onPromotion: Bool, inStock: Bool, minPrice: Double?, maxPrice: Double?,
         onApply: @escaping (CategoryFilterResult) -> Void) {
        self.filters = filters
        self.currency = currency
        self.onApply = onApply

        let rMin = filters?.price_range?.min ?? 0
        var rMax = filters?.price_range?.max ?? 1000
        if rMax <= rMin { rMax = rMin + 1 }
        self.rangeMin = rMin
        self.rangeMax = rMax

        _wBrands = State(initialValue: selBrands)
        _wSubs = State(initialValue: selSubCategories)
        _wPacks = State(initialValue: selPackSizes)
        _wPromo = State(initialValue: onPromotion)
        _wStock = State(initialValue: inStock)
        _lo = State(initialValue: Swift.min(Swift.max(minPrice ?? rMin, rMin), rMax))
        _hi = State(initialValue: Swift.min(Swift.max(maxPrice ?? rMax, rMin), rMax))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    brandsSection
                    Divider()
                    categoriesSection
                    Divider()
                    packSizeSection
                    Divider()
                    priceSection
                    Divider()
                    promotionsSection
                    Divider()
                    availabilitySection
                }
                .padding(16)
            }
            .background(Brand.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") { clearAll() }.foregroundColor(Brand.purple)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundColor(Brand.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
        // Presented from screens that force .preferredColorScheme(.dark); force light.
        .preferredColorScheme(.light)
    }

    // MARK: - Sections

    private var brandsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Brands")
            optionRow("All Brands", nil, wBrands.isEmpty) { wBrands.removeAll() }
            ForEach(filters?.brands ?? []) { b in
                optionRow(b.name ?? "—", b.count, wBrands.contains(b.id)) {
                    if wBrands.contains(b.id) { wBrands.remove(b.id) } else { wBrands.insert(b.id) }
                }
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Categories")
            optionRow("All", nil, wSubs.isEmpty) { wSubs.removeAll() }
            ForEach(filters?.categories ?? []) { c in
                optionRow(c.title ?? "—", c.count, wSubs.contains(c.id)) {
                    if wSubs.contains(c.id) { wSubs.remove(c.id) } else { wSubs.insert(c.id) }
                }
            }
        }
    }

    private var packSizeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Pack Size")
            optionRow("All", nil, wPacks.isEmpty) { wPacks.removeAll() }
            ForEach(filters?.pack_sizes ?? []) { ps in
                optionRow(ps.label ?? ps.key, ps.count, wPacks.contains(ps.key)) {
                    if wPacks.contains(ps.key) { wPacks.remove(ps.key) } else { wPacks.insert(ps.key) }
                }
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Price Range")
            RangeSlider(lo: $lo, hi: $hi, bounds: rangeMin...rangeMax)
                .frame(height: 28)
            HStack {
                Text(CurrencyFmt.format(lo, symbol: currency))
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text(CurrencyFmt.format(hi, symbol: currency) + (hi >= rangeMax ? "+" : ""))
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
        }
    }

    private var promotionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Promotions")
            ForEach(filters?.promotions ?? []) { pr in
                let supported = pr.key == "on_promotion"
                optionRow(pr.label ?? pr.key, pr.count, supported && wPromo,
                          enabled: supported) {
                    wPromo.toggle()
                }
            }
        }
    }

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Availability")
            optionRow("In Stock Only", filters?.availability?.in_stock_count, wStock) {
                wStock.toggle()
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button { clearAll() } label: {
                Text("Reset")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Brand.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button { apply() } label: {
                Text("Apply Filters")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Brand.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Brand.surface.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Row helper

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
    }

    private func optionRow(_ label: String, _ count: Int?, _ checked: Bool,
                           enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 10) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(checked ? Brand.purple : Brand.textTertiary)
                Text(label).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                Spacer()
                if let count {
                    Text("\(count)").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Actions

    private func clearAll() {
        wBrands.removeAll(); wSubs.removeAll(); wPacks.removeAll()
        wPromo = false; wStock = false
        lo = rangeMin; hi = rangeMax
    }

    private func apply() {
        // At an extreme, send no bound (matches Android: min at floor / max at ceiling omit the param).
        let minP: Double? = lo > rangeMin ? lo : nil
        let maxP: Double? = hi < rangeMax ? hi : nil
        onApply(CategoryFilterResult(brands: wBrands, subCategories: wSubs, packSizes: wPacks,
                                     onPromotion: wPromo, inStock: wStock,
                                     minPrice: minP, maxPrice: maxP))
        dismiss()
    }
}

// MARK: - Two-thumb range slider

/// A compact dual-thumb range slider (SwiftUI has no built-in one). Values snap to
/// whole units; thumbs cannot cross. Mirrors the Material `RangeSlider` on Android.
struct RangeSlider: View {
    @Binding var lo: Double
    @Binding var hi: Double
    let bounds: ClosedRange<Double>

    private let thumb: CGFloat = 24
    private let track: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - thumb, 1)
            let span = max(bounds.upperBound - bounds.lowerBound, 0.0001)
            let loX = CGFloat((lo - bounds.lowerBound) / span) * usable + thumb / 2
            let hiX = CGFloat((hi - bounds.lowerBound) / span) * usable + thumb / 2

            ZStack(alignment: .leading) {
                Capsule().fill(Brand.border).frame(height: track)
                Capsule().fill(Brand.purple)
                    .frame(width: max(0, hiX - loX), height: track)
                    .offset(x: loX)
                thumbView.position(x: loX, y: geo.size.height / 2)
                    .gesture(drag(usable: usable, span: span, isLow: true))
                thumbView.position(x: hiX, y: geo.size.height / 2)
                    .gesture(drag(usable: usable, span: span, isLow: false))
            }
            .frame(height: geo.size.height)
            .coordinateSpace(name: "rangeSlider")
        }
    }

    private var thumbView: some View {
        Circle().fill(Brand.purple)
            .frame(width: thumb, height: thumb)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private func drag(usable: CGFloat, span: Double, isLow: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("rangeSlider"))
            .onChanged { value in
                let ratio = Double((value.location.x - thumb / 2) / usable)
                let raw = (bounds.lowerBound + ratio * span).rounded()
                let clamped = Swift.min(Swift.max(raw, bounds.lowerBound), bounds.upperBound)
                if isLow {
                    lo = Swift.min(clamped, hi)
                } else {
                    hi = Swift.max(clamped, lo)
                }
            }
    }
}
