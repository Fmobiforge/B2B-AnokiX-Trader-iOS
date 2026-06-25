import SwiftUI
import UIKit

// MARK: - Labeled text field (light card style, matches Android RegFieldBox)

struct LabeledField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .sentences
    var disableAutocorrect: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled(disableAutocorrect)
                .font(.system(size: 15))
                .foregroundColor(Brand.textPrimary)
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Secure field with show/hide toggle

struct LabeledSecureField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = "••••••••"
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            HStack {
                Group {
                    if visible { TextField(placeholder, text: $text) }
                    else { SecureField(placeholder, text: $text) }
                }
                .font(.system(size: 15))
                .foregroundColor(Brand.textPrimary)
                Button { visible.toggle() } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .foregroundColor(Brand.textSecondary)
                }
            }
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Dropdown field (chevron on the RIGHT) — matches the Android dropdown style

/// A tappable field that looks like an input but opens a picker. The drop/chevron
/// icon sits on the trailing (right) edge of the control, mirroring the Android UI.
struct DropdownField: View {
    let title: String
    let value: String
    var placeholder: String = "Select"
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(value.isEmpty ? placeholder : value)
                        .font(.system(size: 15))
                        .foregroundColor(value.isEmpty ? Brand.textTertiary : Brand.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.textSecondary)
                }
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Dropdown backed by a Menu (reliable single-select, no action-sheet glitches)

/// Same look as `DropdownField` but opens a native pull-down `Menu` instead of a
/// `.confirmationDialog`. Menus render as opaque pop-ups, so they avoid the
/// transparent-backdrop issue action sheets hit when stacked with other modals.
struct MenuDropdown<MenuContent: View>: View {
    let title: String
    let value: String
    var placeholder: String = "Select"
    @ViewBuilder var menuContent: MenuContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            Menu {
                menuContent
            } label: {
                HStack(spacing: 8) {
                    Text(value.isEmpty ? placeholder : value)
                        .font(.system(size: 15))
                        .foregroundColor(value.isEmpty ? Brand.textTertiary : Brand.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.textSecondary)
                }
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Selectable chip used in pickers and the categories/days steps

struct SelectChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selected ? .white : Brand.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Brand.purple : Brand.surface)
                .overlay(Capsule().stroke(selected ? Brand.purple : Brand.border, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Horizontal step indicator for the wizard

struct StepBar: View {
    let count: Int
    let current: Int   // 0-based

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(i <= current ? Brand.purple : Brand.purpleLight)
                        .frame(width: 26, height: 26)
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(i <= current ? .white : Brand.purple)
                }
                if i < count - 1 {
                    Rectangle()
                        .fill(i < current ? Brand.purple : Brand.purpleLight)
                        .frame(height: 2)
                }
            }
        }
    }
}

// MARK: - Labeled wizard stepper (numbered circles + step names + connectors)

/// Horizontal, auto-scrolling stepper mirroring the Android / Distributor Create
/// Account chrome: a numbered circle and a step label for each step, joined by a
/// short connector. Completed steps show a check; the current step is highlighted.
struct WizardStepper: View {
    let titles: [String]
    let current: Int   // 0-based

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(titles.indices, id: \.self) { i in
                        if i > 0 {
                            Rectangle()
                                .fill(Brand.border)
                                .frame(width: 20, height: 1)
                                .padding(.horizontal, 6)
                        }
                        item(i)
                            .id(i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Brand.surface)
            .onChange(of: current) { newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func item(_ i: Int) -> some View {
        let state = stepState(i)
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(state == .upcoming ? Brand.surface : Brand.purple)
                    .overlay(Circle().stroke(state == .upcoming ? Brand.border : Brand.purple,
                                             lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(state == .upcoming ? Brand.textSecondary : .white)
                }
            }
            Text(titles[i])
                .font(.system(size: 13, weight: state == .current ? .bold : .regular))
                .foregroundColor(labelColor(state))
                .fixedSize()
        }
        .padding(.horizontal, 6)
    }

    private enum StepState { case done, current, upcoming }

    private func stepState(_ i: Int) -> StepState {
        if i < current { return .done }
        if i == current { return .current }
        return .upcoming
    }

    private func labelColor(_ state: StepState) -> Color {
        switch state {
        case .done:     return Brand.textPrimary
        case .current:  return Brand.purple
        case .upcoming: return Brand.textSecondary
        }
    }
}

// MARK: - Step intro (navy heading + grey subtitle)

/// The title/subtitle pair shown at the top of each Create Account step,
/// matching the Android `top_title` heading + secondary subtitle.
struct StepIntro: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Brand.topTitle)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tinted information box (e.g. "Account sign-in")

struct InfoBox: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Brand.purple)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.purpleLight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Removable chip used for selected categories / distributors

struct RemovableChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.purple)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Brand.purple)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Brand.purpleLight)
        .clipShape(Capsule())
    }
}
