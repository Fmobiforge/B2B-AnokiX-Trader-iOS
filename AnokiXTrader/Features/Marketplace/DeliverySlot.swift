import Foundation

/// A single selectable delivery window (one date + one time range), generated
/// locally from the trader's `preferred_delivery_days` string (mirrors the
/// Android `DeliverySlot`).
///
/// Format of `preferred_delivery_days`, e.g.
/// `"1:8.00-12,15-22/2:8.00-22,-/3:8.00-22,/4:8.00-22,/5:8.00-22"`:
///   - entries separated by `/`
///   - each entry `<dayOfWeek>:<range>,<range>` where dayOfWeek 1=Monday … 7=Sunday
///   - each range `start-end`; `.` is the minute separator (`8.00` = 08:00),
///     a bare hour means `:00` (`12` = 12:00)
///   - an empty range or `-` is ignored
///
/// Slots are generated from tomorrow for the next 4 weeks.
struct DeliverySlot: Identifiable, Hashable {
    let id = UUID()
    let deliveryDate: String   // yyyy-MM-dd (API)
    let startDisplay: String   // HH:mm
    let endDisplay: String
    let startApi: String       // HH:mm:ss
    let endApi: String
    let dateLabel: String      // e.g. "Tomorrow (Fri, 26 Jun)" / "Mon (29 Jun)"

    /// Full label, e.g. "Mon (29 Jun) 08:00 - 12:00".
    var label: String { "\(dateLabel) \(startDisplay) - \(endDisplay)" }

    private static let weeksAhead = 4

    /// Generate the selectable slots for the next 4 weeks (starting tomorrow).
    static func generate(from preferredDeliveryDays: String?) -> [DeliverySlot] {
        let byDay = parse(preferredDeliveryDays)
        guard !byDay.isEmpty else { return [] }

        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")

        let apiDate = DateFormatter(); apiDate.locale = cal.locale
        apiDate.dateFormat = "yyyy-MM-dd"
        let weekday = DateFormatter(); weekday.locale = cal.locale
        weekday.dateFormat = "EEE"
        let dayMonth = DateFormatter(); dayMonth.locale = cal.locale
        dayMonth.dateFormat = "dd MMM"

        let today = cal.startOfDay(for: Date())
        var slots: [DeliverySlot] = []

        for offset in 1...(weeksAhead * 7) {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let iso = isoDayOfWeek(cal.component(.weekday, from: date))
            guard let ranges = byDay[iso] else { continue }

            let prefix = relativePrefix(daysFromToday: offset)
            let wd = weekday.string(from: date)
            let dm = dayMonth.string(from: date)
            let dateLabel = prefix != nil
                ? "\(prefix!) (\(wd), \(dm))"
                : "\(wd) (\(dm))"
            let iso8601 = apiDate.string(from: date)

            for range in ranges {
                slots.append(DeliverySlot(deliveryDate: iso8601,
                                          startDisplay: range.0, endDisplay: range.1,
                                          startApi: range.0 + ":00", endApi: range.1 + ":00",
                                          dateLabel: dateLabel))
            }
        }
        return slots
    }

    // MARK: - Parsing

    /// ISO day (1=Mon..7=Sun) → list of (startDisplay, endDisplay) ranges.
    private static func parse(_ raw: String?) -> [Int: [(String, String)]] {
        var map: [Int: [(String, String)]] = [:]
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return map }
        for entry in raw.split(separator: "/") {
            let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let day = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                  (1...7).contains(day) else { continue }
            var ranges: [(String, String)] = []
            for r in parts[1].split(separator: ",", omittingEmptySubsequences: false) {
                if let range = parseRange(String(r)) { ranges.append(range) }
            }
            if !ranges.isEmpty { map[day] = ranges }
        }
        return map
    }

    /// "8.00-12" → ("08:00", "12:00"); nil for empty / "-".
    private static func parseRange(_ range: String) -> (String, String)? {
        let r = range.trimmingCharacters(in: .whitespaces)
        if r.isEmpty || r == "-" { return nil }
        let halves = r.split(separator: "-", omittingEmptySubsequences: false)
        guard halves.count == 2,
              let start = normalizeTime(String(halves[0])),
              let end = normalizeTime(String(halves[1])) else { return nil }
        return (start, end)
    }

    /// "8.00" → "08:00", "12" → "12:00", "15.30" → "15:30".
    private static func normalizeTime(_ t: String) -> String? {
        let s = t.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ":")
        if s.isEmpty { return nil }
        let parts = s.split(separator: ":", omittingEmptySubsequences: false)
        guard let hour = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { return nil }
        var minute = 0
        if parts.count > 1 {
            let mm = parts[1].trimmingCharacters(in: .whitespaces)
            if !mm.isEmpty {
                guard let m = Int(mm) else { return nil }
                minute = m
            }
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }

    /// Calendar weekday (1=Sun..7=Sat) → ISO (1=Mon..7=Sun).
    private static func isoDayOfWeek(_ calWeekday: Int) -> Int {
        calWeekday == 1 ? 7 : calWeekday - 1
    }

    private static func relativePrefix(daysFromToday: Int) -> String? {
        switch daysFromToday {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return nil
        }
    }
}
