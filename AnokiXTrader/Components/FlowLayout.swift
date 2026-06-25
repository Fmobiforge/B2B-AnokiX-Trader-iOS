import SwiftUI

/// iOS 16 `Layout` that arranges subviews left-to-right, wrapping to new rows
/// when the available width runs out (used for the order product chips).
struct FlowLayout: Layout {
    var hSpacing: CGFloat = 6
    var vSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Convenience wrapper: lay out `items` with `content` using a wrapping `FlowLayout`.
struct FlexibleWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        FlowLayout(hSpacing: 6, vSpacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                content(item)
            }
        }
    }
}

/// Wrapping capsule chips for plain text labels (e.g. order product names).
struct WrappingTextChips: View {
    let items: [String]

    var body: some View {
        FlexibleWrap(items: items) { name in
            Text(name)
                .font(.system(size: 11)).foregroundColor(Brand.textPrimary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Brand.surfaceVariant)
                .overlay(Capsule().stroke(Brand.border, lineWidth: 1))
                .clipShape(Capsule())
        }
    }
}

/// Horizontal scroll of removable chips (register categories / distributors).
struct HorizontalRemovableChips: View {
    let items: [(Int, String)]
    let onRemove: (Int) -> Void

    init(_ items: [(Int, String)], onRemove: @escaping (Int) -> Void) {
        self.items = items
        self.onRemove = onRemove
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { id, label in
                    RemovableChip(label: label) { onRemove(id) }
                }
            }
        }
    }
}
