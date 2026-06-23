import SwiftUI

/// Maps a free-text badge to the portal's colour tones.
func badgeTone(_ badge: String) -> (fg: Color, bg: Color) {
    switch badge.lowercased() {
    case "settled", "active", "loyal", "vip", "ready", "delivered", "success", "in stock", "resolved":
        return (Brand.success, Brand.successBg)
    case "pending", "upcoming", "generating", "low stock", "regular", "in_progress", "in progress", "out for delivery":
        return (Brand.warning, Brand.warningBg)
    case "refunded", "new", "accepted", "picking", "packing":
        return (Brand.info, Brand.infoBg)
    case "failed", "out of stock", "open", "cancelled", "damaged", "expired":
        return (Brand.danger, Brand.dangerBg)
    default:
        return (Brand.purple, Brand.purpleLight)
    }
}

/// Generic two-line + badge row used by Payments / Customers / Offers / Top Products / Low Stock.
struct GenericRow: View {
    let item: ListItem
    var leadingInitial: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let tone = badgeTone(item.badge)
        Button { onTap?() } label: {
            HStack(spacing: 12) {
                if leadingInitial {
                    InitialBadge(text: String(item.title.prefix(1)), color: Brand.purple, size: 42)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    Text(item.subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                StatusBadge(text: item.badge, fg: tone.fg, bg: tone.bg)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A titled card wrapping a list of generic rows with dividers.
struct ListCard<Content: View>: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: title, actionTitle: actionTitle, action: action)
            content
        }
        .card()
    }
}

/// Small KPI / stat tile used in horizontal stat strips.
struct StatTile: View {
    let label: String
    let value: String
    var valueColor: Color = Brand.textPrimary
    var icon: String? = nil
    var iconTint: Color = Brand.purple

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconTint)
                    .frame(width: 34, height: 34)
                    .background(iconTint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(valueColor)
            Text(label).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
    }
}

/// Toast-style transient message (mirrors the Android Toast feedback).
struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.black.opacity(0.85))
            .clipShape(Capsule())
            .shadow(radius: 8)
    }
}

/// View modifier to show a transient toast.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        ZStack {
            content
            if let message {
                VStack {
                    Spacer()
                    Toast(text: message).padding(.bottom, 90)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { self.message = nil }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View { modifier(ToastModifier(message: message)) }
}
