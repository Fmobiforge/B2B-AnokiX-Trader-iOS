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
