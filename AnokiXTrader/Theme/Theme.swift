import SwiftUI

// MARK: - Hex color support

extension Color {
    /// Create a Color from a hex string like "#7C3AED", "7C3AED" or "#FFF".
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        switch s.count {
        case 3: // RGB (12-bit)
            r = Double((rgb >> 8) & 0xF) / 15.0
            g = Double((rgb >> 4) & 0xF) / 15.0
            b = Double(rgb & 0xF) / 15.0
            a = 1.0
        case 8: // ARGB / RRGGBBAA — treat as RRGGBBAA
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default: // 6 digits RRGGBB
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Brand palette (mirrors the Android colors.xml / Trader Portal)

enum Brand {
    static let purple       = Color(hex: "#7C3AED")
    static let purpleDark   = Color(hex: "#5B21B6")
    static let purpleLight  = Color(hex: "#EDE9FE")
    static let purpleTextLt = Color(hex: "#C4B5FD")

    static let background    = Color(hex: "#F1F5F9")
    static let surface       = Color(hex: "#FFFFFF")
    static let surfaceVariant = Color(hex: "#F8FAFC")

    static let textPrimary   = Color(hex: "#0F172A")
    static let textSecondary = Color(hex: "#64748B")
    static let textTertiary  = Color(hex: "#94A3B8")
    static let topTitle      = Color(hex: "#1A237E")   // navy section headings (Android @color/top_title)

    static let border        = Color(hex: "#E2E8F0")
    static let divider       = Color(hex: "#E2E8F0")

    static let success   = Color(hex: "#16A34A")
    static let successBg = Color(hex: "#DCFCE7")
    static let warning   = Color(hex: "#EA580C")
    static let warningBg = Color(hex: "#FFEDD5")
    static let danger    = Color(hex: "#DC2626")
    static let dangerBg  = Color(hex: "#FEE2E2")
    static let info      = Color(hex: "#2563EB")
    static let infoBg    = Color(hex: "#DBEAFE")

    static let loginBg   = Color(hex: "#000920")
    static let drawerBg  = Color(hex: "#000920")
}

// MARK: - Card container

/// White rounded card with the soft border the portal/Android uses everywhere.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Brand.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

extension View {
    /// Wrap any view in the standard card chrome.
    func card(padding: CGFloat = 16) -> some View {
        Card(padding: padding) { self }
    }
}

// MARK: - Status badge (pill)

struct StatusBadge: View {
    let text: String
    var fg: Color = Brand.success
    var bg: Color = Brand.successBg

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
    }
}

// MARK: - Section header used inside scroll screens

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.purple)
            }
        }
    }
}

// MARK: - Primary / chip helpers

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Brand.purple.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Selectable filter chip matching the portal's purple-when-active chips.
struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selected ? .white : Brand.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Brand.purple : Brand.surface)
                .overlay(
                    Capsule().stroke(selected ? Brand.purple : Brand.border, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Coloured square "logo" tile with initials — mirrors the Android tinted thumbs.
struct InitialBadge: View {
    let text: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Text(text)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}
