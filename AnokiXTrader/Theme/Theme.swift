import SwiftUI
import UIKit

// MARK: - Typography (Inter — the Trader Portal / Android typeface)

/// Inter faces bundled in Resources/Fonts and listed under UIAppFonts in Info.plist.
enum AppFont {
    /// False if the faces aren't bundled — every helper then falls back to the system font,
    /// so a missing font can never break a screen.
    static let available: Bool = UIFont(name: "Inter-Regular", size: 12) != nil

    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Inter-Bold"
        case .semibold:             return "Inter-SemiBold"
        case .medium:               return "Inter-Medium"
        default:                    return "Inter-Regular"
        }
    }

    /// UIKit counterpart, for UINavigationBar / UISegmentedControl appearance.
    static func uiFont(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Inter-Bold"
        case .semibold:             name = "Inter-SemiBold"
        case .medium:               name = "Inter-Medium"
        default:                    name = "Inter-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

extension Font {
    /// Inter at a fixed point size — drop-in for `.system(size:weight:)` (same fixed sizing,
    /// no Dynamic Type scaling), so layouts keep their metrics.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard AppFont.available else { return .system(size: size, weight: weight) }
        return .custom(AppFont.name(for: weight), fixedSize: size)
    }
}

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

/// Aligned with the Trader Portal (trader.anokix.com): navy ink (#1A237E) for titles +
/// body text, #5C6B7A secondary text, #F5F7FA canvas, #DCE1E8 card borders, violet for
/// primary actions, portal blue (#0D47A1) for links / icon tiles, #00091F sidebar navy.
enum Brand {
    static let purple       = Color(hex: "#7C3AED")
    static let purpleDark   = Color(hex: "#5B21B6")
    static let purpleLight  = Color(hex: "#EDE9FE")
    static let purpleTextLt = Color(hex: "#C4B5FD")

    static let background    = Color(hex: "#F5F7FA")
    static let surface       = Color(hex: "#FFFFFF")
    static let surfaceVariant = Color(hex: "#F8FAFC")

    static let textPrimary   = Color(hex: "#1A237E")
    static let textSecondary = Color(hex: "#5C6B7A")
    static let textTertiary  = Color(hex: "#94A3B8")
    static let topTitle      = Color(hex: "#1A237E")   // navy section headings (Android @color/top_title)

    static let border        = Color(hex: "#DCE1E8")
    static let divider       = Color(hex: "#E8ECF1")

    // Portal accents
    static let blue          = Color(hex: "#0D47A1")
    static let blueBg        = Color(hex: "#E3EAF5")
    static let sky           = Color(hex: "#29B6F6")
    static let indigo        = Color(hex: "#6366F1")
    static let violet        = Color(hex: "#8B5CF6")
    static let successStrong = Color(hex: "#2E7D32")
    static let warningStrong = Color(hex: "#FF6F00")
    static let drawerMuted   = Color.white.opacity(0.72)

    /// Portal login / welcome button: sky → blue → violet.
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "#29B6F6"), Color(hex: "#4F8DF5"), Color(hex: "#8B5CF6")],
        startPoint: .leading, endPoint: .trailing)
    /// Portal sidebar active item: indigo → violet.
    static let navActiveGradient = LinearGradient(
        colors: [Color(hex: "#6366F1").opacity(0.9), Color(hex: "#8B5CF6").opacity(0.85)],
        startPoint: .leading, endPoint: .trailing)

    static let success   = Color(hex: "#16A34A")
    static let successBg = Color(hex: "#DCFCE7")
    static let warning   = Color(hex: "#EA580C")
    static let warningBg = Color(hex: "#FFEDD5")
    static let danger    = Color(hex: "#DC2626")
    static let dangerBg  = Color(hex: "#FEE2E2")
    static let info      = Color(hex: "#2563EB")
    static let infoBg    = Color(hex: "#DBEAFE")

    static let loginBg   = Color(hex: "#00091F")
    static let drawerBg  = Color(hex: "#00091F")
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Brand.border, lineWidth: 1)
            )
            // Portal card shadow: 0 1px 3px rgba(13,71,161,.06).
            .shadow(color: Brand.blue.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

extension View {
    /// Wrap any view in the standard card chrome.
    func card(padding: CGFloat = 16) -> some View {
        Card(padding: padding) { self }
    }

    /// Grows a small control's *hit* area towards the 44×44pt minimum without moving
    /// anything on screen — the outer negative padding hands the extra space back to the
    /// parent, so layout is unchanged.
    ///
    /// The header icons are 18–20pt glyphs, which on their own are only about half the
    /// minimum target. That is why a first tap on the drawer button so often appeared to
    /// do nothing: it simply landed outside the button.
    func tapTarget(inset: CGFloat = 12) -> some View {
        padding(inset)
            .contentShape(Rectangle())
            .padding(-inset)
    }
}

// MARK: - Status badge (pill)

struct StatusBadge: View {
    let text: String
    var fg: Color = Brand.success
    var bg: Color = Brand.successBg

    var body: some View {
        Text(text)
            .font(.app(11, .semibold))
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
                .font(.app(16, .semibold))
                .foregroundColor(Brand.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.app(13, .semibold))
                    .foregroundColor(Brand.purple)
            }
        }
    }
}

// MARK: - Primary / chip helpers

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(15, .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Brand.purple.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .font(.app(13, .medium))
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
            .font(.app(size * 0.36, .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}
