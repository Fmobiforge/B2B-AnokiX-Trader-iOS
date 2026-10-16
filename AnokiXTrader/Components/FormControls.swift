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
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled(disableAutocorrect)
                .font(.app(15))
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
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            HStack {
                Group {
                    if visible { TextField(placeholder, text: $text) }
                    else { SecureField(placeholder, text: $text) }
                }
                .font(.app(15))
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
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(value.isEmpty ? placeholder : value)
                        .font(.app(15))
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

// MARK: - Single-select field backed by a bottom sheet (theme-safe dropdown)

/// A tappable field that looks like `DropdownField` and opens a self-styled bottom
/// sheet of options. Replaces the earlier `Menu`-based dropdown: a native `Menu`
/// pop-up inherits the surrounding foreground color, so on the light-pinned auth /
/// registration screens its items rendered white-on-white and were invisible. The
/// sheet below draws its own rows with explicit Brand colors, so it always reads
/// clearly regardless of the ambient theme.
///
/// `options` are `(id, label)` pairs — `id` is the stored code, `label` is shown to
/// the user — and `selection` is bound to the chosen `id`. Tuples are unlabeled to
/// match the codebase convention (`MultiSelectSheet`) and avoid array tuple-label
/// conversion issues when call sites pass `.map { ($0.code, $0.label) }`.
struct SelectField: View {
    let title: String
    var placeholder: String = "Select"
    let options: [(String, String)]
    @Binding var selection: String
    @State private var show = false

    private var currentLabel: String {
        options.first { $0.0 == selection }?.1 ?? ""
    }

    var body: some View {
        DropdownField(title: title, value: currentLabel, placeholder: placeholder) { show = true }
            .sheet(isPresented: $show) {
                SelectOptionsSheet(title: title, options: options, selection: $selection)
            }
    }
}

/// The bottom sheet for `SelectField`: a titled list of tappable rows, the selected
/// one marked with a purple check. Height fits the content (capped), always light.
/// Also reused directly by compact pill dropdowns (e.g. the Finances filter bar),
/// which want the pill trigger look rather than a full `DropdownField`.
struct SelectOptionsSheet: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.app(17, .bold))
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
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                        Button {
                            selection = opt.0
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(opt.1)
                                    .font(.app(16, selection == opt.0 ? .semibold : .regular))
                                    .foregroundColor(selection == opt.0 ? Brand.purple : Brand.textPrimary)
                                Spacer(minLength: 8)
                                if selection == opt.0 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Brand.purple)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx < options.count - 1 {
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.surface.ignoresSafeArea())
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)   // always render light, even in system Dark Mode
    }

    /// Fit the sheet to its rows (header + rows), capped so long lists still scroll.
    private var sheetHeight: CGFloat {
        let header: CGFloat = 64
        let row: CGFloat = 54
        return min(header + CGFloat(options.count) * row + 20, 440)
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
                .font(.app(13, .medium))
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
                        .font(.app(12, .bold))
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
    /// When set, each step is tappable (jump straight to it) — used by the Business
    /// editor to match Android's tappable stepper. Defaults to nil (display-only).
    var onSelect: ((Int) -> Void)? = nil

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
                        Group {
                            if let onSelect {
                                Button { onSelect(i) } label: { item(i) }
                                    .buttonStyle(.plain)
                            } else {
                                item(i)
                            }
                        }
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
                        .font(.app(12, .bold))
                        .foregroundColor(state == .upcoming ? Brand.textSecondary : .white)
                }
            }
            Text(titles[i])
                .font(.app(13, state == .current ? .bold : .regular))
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
                .font(.app(20, .bold))
                .foregroundColor(Brand.topTitle)
            Text(subtitle)
                .font(.app(13))
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
                .font(.app(13, .bold))
                .foregroundColor(Brand.purple)
            Text(text)
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.purpleLight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Phone entry with a country dial-code picker

/// A phone row: a tappable flag + dial-code button (opens `CountryPickerSheet`),
/// a divider, then the national-number field. Mirrors the Distributor app's
/// profile phone row; shared by Settings → Profile and the Business editor.
struct PhoneEntryField: View {
    let title: String
    @Binding var country: Country
    @Binding var text: String
    var placeholder: String = "Phone number"
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            HStack(spacing: 8) {
                Button { showPicker = true } label: {
                    HStack(spacing: 4) {
                        Text(country.flag).font(.app(15))
                        Text(country.dialCode).font(.app(15, .semibold))
                            .foregroundColor(Brand.textPrimary)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Brand.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                Rectangle().fill(Brand.border).frame(width: 1, height: 24)
                TextField(placeholder, text: $text)
                    .keyboardType(.phonePad)
                    .font(.app(15))
                    .foregroundColor(Brand.textPrimary)
            }
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showPicker) {
            CountryPickerSheet(selection: $country)
        }
    }
}

/// Phone string helpers shared by Profile + Business editors, matching the
/// Distributor app's `splitPhone`/`fullPhone` (dial code kept WITH the leading '+').
enum PhoneCompose {
    /// Split a stored phone ("+27821234567") into (country, national digits).
    /// Falls back to the default country when there's no recognizable dial code.
    static func split(_ raw: String) -> (Country, String) {
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("+") {
            // Longest matching dial code wins (e.g. "+1" vs a hypothetical "+1242").
            let match = Countries.all
                .filter { value.hasPrefix($0.dialCode) }
                .max { $0.dialCode.count < $1.dialCode.count }
            if let c = match {
                return (c, String(value.dropFirst(c.dialCode.count)).filter { $0.isNumber })
            }
        }
        return (Countries.default, value.filter { $0.isNumber })
    }

    /// Country dial code + national number (a single leading 0 dropped). Empty in → empty out.
    static func full(country: Country, national: String) -> String {
        var number = national.filter { $0.isNumber }
        if number.isEmpty { return "" }
        if number.hasPrefix("0") { number.removeFirst() }
        return country.dialCode + number
    }
}

// MARK: - Per-day delivery-hours grid (shared by Create Account + Business editor)

/// One row of the per-day delivery-hours grid (0=Sun..6=Sat). Each day can have up to
/// two windows (open1-close1, open2-close2). 1:1 with the Android `item_delivery_day` row.
struct DeliveryRow: Identifiable {
    let index: Int
    let abbr: String
    var checked = false
    var open1 = "", close1 = "", open2 = "", close2 = ""
    var id: Int { index }
}

/// Model + payload (de)serialization for the delivery grid. Payload index order is
/// 0=Sun..6=Sat. Exact ports of the Android `DAY_NAMES`/`deliveryDaysString`/
/// `prefillDeliveryDays`/`fmtHour`.
enum DeliveryGrid {
    static let dayOrder = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// 7 empty rows in payload-index order.
    static func makeRows() -> [DeliveryRow] {
        dayOrder.enumerated().map { DeliveryRow(index: $0.offset, abbr: $0.element) }
    }

    /// Payload day number → row index. The payload is ISO (1=Mon…7=Sun) while rows run
    /// 0=Sun…6=Sat, so 1–6 line up and only Sunday moves. A legacy `0` also means Sunday.
    static func rowIndex(forDay day: Int) -> Int? {
        if day == 0 || day == 7 { return 0 }            // Sunday (legacy 0 / ISO 7)
        return (1...6).contains(day) ? day : nil
    }

    /// "1:8.00-18.00/3:8.00-18.00/5:8.00-18.00" — ONLY the ticked days, keyed by ISO day
    /// (1=Mon…7=Sun) and emitted in Mon→Sun order. This is the shape the server stores and
    /// that `DeliverySlot` reads when building order slots; it drops the old leading
    /// abbreviation CSV and no longer writes hours for unticked days (which used to make
    /// every weekday a delivery day, and lost Sunday entirely because `DeliverySlot`
    /// rejects day 0).
    static func serialize(_ rows: [DeliveryRow]) -> String {
        (1...7).compactMap { day -> String? in
            guard let i = rowIndex(forDay: day), rows.indices.contains(i), rows[i].checked else { return nil }
            let row = rows[i]
            let o1 = row.open1.trimmingCharacters(in: .whitespaces)
            let c1 = row.close1.trimmingCharacters(in: .whitespaces)
            var slot = (o1.isEmpty && c1.isEmpty) ? "8.00-18.00" : fmtHour(o1) + "-" + fmtHour(c1)
            let o2 = row.open2.trimmingCharacters(in: .whitespaces)
            let c2 = row.close2.trimmingCharacters(in: .whitespaces)
            if !o2.isEmpty || !c2.isEmpty { slot += "," + fmtHour(o2) + "-" + fmtHour(c2) }
            return "\(day):\(slot)"
        }.joined(separator: "/")
    }

    /// Selected-day abbreviations only, e.g. "Mon,Wed,Fri" (no hours). Used by Create
    /// Account, whose captured `api/trader/register` payload sends plain CSV (the hours
    /// grid is still shown, but registration submits days only).
    static func selectedDaysCSV(_ rows: [DeliveryRow]) -> String {
        rows.filter { $0.checked }.map { $0.abbr }.joined(separator: ",")
    }

    /// Prefill rows from the stored string. Handles both shapes:
    ///
    /// - canonical (what the server stores, and what `DeliverySlot` reads):
    ///   `"1:8.00-18.00/3:8.00-18.00/5:8.00-18.00"` — ONLY the delivery days are listed, so a
    ///   day that carries hours IS a selected day and must be ticked.
    /// - legacy (what this grid used to write): a leading `"Mon,Wed,Fri"` CSV followed by hours
    ///   for ALL seven days. There the CSV is the only reliable source of selection, since
    ///   unchecked days still carry default hours.
    static func apply(_ raw: String, to rows: inout [DeliveryRow]) {
        guard !raw.isEmpty else { return }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

        // A first segment without a ':' is the legacy day-abbreviation CSV.
        let hasLegacyCSV = !(parts.first?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
            && !(parts[0].contains(":"))

        if hasLegacyCSV {
            let selected = Set(parts[0].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            for i in rows.indices { rows[i].checked = selected.contains(rows[i].abbr) }
        }

        for seg in parts {
            guard let colon = seg.firstIndex(of: ":") else { continue }   // legacy CSV, or junk
            guard let day = Int(seg[..<colon].trimmingCharacters(in: .whitespaces)),
                  let idx = rowIndex(forDay: day), rows.indices.contains(idx) else { continue }
            let slots = seg[seg.index(after: colon)...]
                .split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            var filled = false
            if slots.count > 0 { filled = fillSlot(&rows[idx], slots[0], second: false) }
            if slots.count > 1 { filled = fillSlot(&rows[idx], slots[1], second: true) || filled }
            // Canonical strings list delivery days only, so real hours imply a ticked day.
            if filled && !hasLegacyCSV { rows[idx].checked = true }
        }
    }

    /// - Returns: true when the slot carried a real time range (so the day counts as selected).
    @discardableResult
    private static func fillSlot(_ row: inout DeliveryRow, _ slot: String, second: Bool) -> Bool {
        let s = slot.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s != "-" else { return false }
        let oc = s.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard oc.count == 2 else { return false }
        if second { row.open2 = oc[0]; row.close2 = oc[1] }
        else { row.open1 = oc[0]; row.close1 = oc[1] }
        return true
    }

    /// "" → "0.00"; "8" → "8.00"; "8.30" kept.
    static func fmtHour(_ v: String) -> String {
        if v.isEmpty { return "0.00" }
        return v.contains(".") ? v : v + ".00"
    }
}

// MARK: - Reusable delivery-grid view

/// The DAY · OPEN · CLOSE · OPEN · CLOSE grid bound to `[DeliveryRow]`. Shared by the
/// Create Account Distributor step and the Business editor.
struct DeliveryHoursGrid: View {
    @Binding var rows: [DeliveryRow]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("DAY").frame(maxWidth: .infinity, alignment: .leading)
                Text("OPEN").frame(maxWidth: .infinity)
                Text("CLOSE").frame(maxWidth: .infinity)
                Text("OPEN").frame(maxWidth: .infinity)
                Text("CLOSE").frame(maxWidth: .infinity)
            }
            .font(.app(11)).foregroundColor(Brand.textSecondary)

            ForEach($rows) { $row in
                HStack(spacing: 6) {
                    Button { $row.checked.wrappedValue.toggle() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: row.checked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16))
                                .foregroundColor(row.checked ? Brand.purple : Brand.textTertiary)
                            Text(row.abbr).font(.app(13)).foregroundColor(Brand.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    timeCell($row.open1)
                    timeCell($row.close1)
                    timeCell($row.open2)
                    timeCell($row.close2)
                }
            }
        }
        .padding(10)
        .background(Brand.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// One numeric hour cell (e.g. "8" → saved as "8.00").
    private func timeCell(_ value: Binding<String>) -> some View {
        TextField("—", text: value)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.app(13))
            .foregroundColor(Brand.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
    }
}

// MARK: - Removable chip used for selected categories / distributors

struct RemovableChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.app(13, .medium))
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
