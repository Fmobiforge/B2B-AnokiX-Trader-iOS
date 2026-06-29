import SwiftUI
import SwiftyJSON

// MARK: - Option types

/// A selectable dropdown option (stored `value` sent to the API + shown `label`).
struct SettingsOption: Identifiable, Hashable {
    let value: String
    let label: String
    var id: String { value }
}

/// A notification toggle definition.
struct NotifToggle: Identifiable, Hashable {
    let key: String
    let title: String
    let desc: String
    var id: String { key }
}

/// A timezone option built from base-info (value = IANA name, label adds the GMT offset).
struct TimezoneOption: Identifiable, Hashable {
    let value: String
    let label: String
    var id: String { value }
    init(json: JSON) {
        let zone = json["time_zone"].string ?? json["name"].stringValue
        value = zone
        let offset = json["time_offset"].int ?? json["utc_offset"].int ?? 0
        label = "\(zone) (\(TimezoneOption.gmt(offset)))"
    }
    static func gmt(_ seconds: Int) -> String {
        let mins = seconds / 60
        let h = abs(mins) / 60, m = abs(mins) % 60
        let sign = mins < 0 ? "-" : "+"
        return m == 0 ? "GMT\(sign)\(h)" : String(format: "GMT%@%d:%02d", sign, h, m)
    }
}

enum SettingsOptions {
    // Currency — value sent to the API (ZAR=1, USD=2, EUR=3 per requirements); label is the code.
    static let currencies = [
        SettingsOption(value: "1", label: "ZAR"),
        SettingsOption(value: "2", label: "USD"),
        SettingsOption(value: "3", label: "EUR"),
    ]
    static let languages = [
        SettingsOption(value: "en", label: "English"),
        SettingsOption(value: "af", label: "Afrikaans"),
        SettingsOption(value: "zu", label: "Zulu"),
    ]
    static let dateFormats = [
        SettingsOption(value: "DD MMM YYYY", label: "19 May 2024"),
        SettingsOption(value: "MM/DD/YYYY", label: "05/19/2024"),
        SettingsOption(value: "YYYY-MM-DD", label: "2024-05-19"),
    ]

    /// Notification toggles — verbatim from the design.
    static let toggles = [
        NotifToggle(key: "orderAlerts", title: "Order Alerts",
                    desc: "Get notified when new orders are placed."),
        NotifToggle(key: "lowStockAlerts", title: "Low Stock Alerts",
                    desc: "Receive alerts when products fall below minimum stock."),
        NotifToggle(key: "deliveryUpdates", title: "Delivery Updates",
                    desc: "Track delivery status changes and delays."),
        NotifToggle(key: "financeReminders", title: "Finance Reminders",
                    desc: "Reminders for overdue invoices and payments."),
        NotifToggle(key: "reportReady", title: "Report Ready",
                    desc: "Notify when scheduled reports are generated."),
    ]
    static var toggleKeys: [String] { toggles.map(\.key) }

    /// Map a stored currency ("ZAR"/"USD"/"EUR" code or "1"/"2"/"3" id) to its option value.
    static func currencyValue(forStored stored: String) -> String {
        let codes = ["ZAR": "1", "USD": "2", "EUR": "3"]
        if let v = codes[stored.uppercased()] { return v }
        if currencies.contains(where: { $0.value == stored }) { return stored }
        return "1"
    }
}

// MARK: - DTOs

struct ProfileUser {
    var firstName: String, lastName: String, email: String, roleLabel: String
    init(json: JSON) {
        firstName = json["first_name"].stringValue
        lastName = json["last_name"].stringValue
        email = json["email"].stringValue
        let role = json["role_label"].string
        roleLabel = (role?.isEmpty == false) ? role! : "Trader"
    }
}

struct PreferencesDTO {
    var language: String, currency: String, timezone: String, dateFormat: String
    var notifications: [String: Bool]   // resolved per known key (missing/array => ON)
    init(json: JSON) {
        language = json["language"].string ?? "en"
        currency = json["currency"].string ?? "ZAR"
        timezone = json["timezone"].string ?? "Africa/Johannesburg"
        dateFormat = json["date_format"].string ?? "DD MMM YYYY"
        let n = json["notifications"]
        var flags: [String: Bool] = [:]
        for key in SettingsOptions.toggleKeys { flags[key] = n[key].bool ?? true }
        notifications = flags
    }
}

struct BusinessDoc: Identifiable {
    let id = UUID()
    let fileURL: String
    let originalName: String
    init(json: JSON) {
        fileURL = json["file_url"].stringValue
        originalName = json["original_name"].stringValue
    }
}

struct BusinessDocGroup: Identifiable {
    let id = UUID()
    let label: String
    let docs: [BusinessDoc]
    var uploaded: Bool { !docs.isEmpty }
}

struct BusinessProfileDTO {
    var traderCode: String, businessName: String, tradingName: String
    var businessEmail: String, businessPhone: String, registrationNumber: String
    var idNumber: String, passportNumber: String, address: String, status: String
    var documents: [BusinessDocGroup]

    init(json: JSON) {
        traderCode = json["trader_code"].stringValue
        businessName = json["business_name"].stringValue
        tradingName = json["trading_name"].stringValue
        businessEmail = json["business_email"].stringValue
        businessPhone = json["business_phone_number"].stringValue
        registrationNumber = json["business_registration_number"].stringValue
        idNumber = json["id_number"].stringValue
        passportNumber = json["passport_number"].stringValue
        address = json["address"].stringValue
        status = json["status"].stringValue
        let d = json["documents"]
        let mapping: [(String, String)] = [
            ("registration_document", "Business Registration Document"),
            ("id_document", "Owner ID Document"),
            ("proof_of_address", "Proof of Address"),
            ("store_front_photo", "Store Front Photo"),
            ("store_interior_photo", "Store Interior Photo"),
            ("additional_document", "Additional Documents"),
        ]
        documents = mapping.map { key, label in
            BusinessDocGroup(label: label, docs: (d[key].array ?? []).map(BusinessDoc.init(json:)))
        }
    }
}

// MARK: - Store

@MainActor
final class SettingsStore: ObservableObject {
    // Profile
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var roleLabel = "Trader"
    @Published var companyName = ""

    // Preferences (values are what the API expects)
    @Published var currency = "1"
    @Published var timezone = "Africa/Johannesburg"
    @Published var dateFormat = "DD MMM YYYY"
    @Published var language = "en"
    @Published var timezones: [TimezoneOption] = []

    // Notifications
    @Published var toggles: [String: Bool] =
        Dictionary(uniqueKeysWithValues: SettingsOptions.toggleKeys.map { ($0, true) })

    // Security
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""

    // Business (read-only summary)
    @Published var business: BusinessProfileDTO?

    // UI state
    @Published var loaded = false
    @Published var savingProfile = false
    @Published var savingPrefs = false
    @Published var savingNotifications = false
    @Published var savingPassword = false
    @Published var toast: String?

    var initials: String {
        let a = firstName.first.map(String.init) ?? ""
        let b = lastName.first.map(String.init) ?? ""
        if !a.isEmpty, !b.isEmpty { return (a + b).uppercased() }
        if !a.isEmpty { return a.uppercased() }
        return email.first.map { String($0).uppercased() } ?? "?"
    }

    var fullName: String {
        let n = (firstName + " " + lastName).trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? email : n
    }

    func load() async {
        if let user = try? await APIClient.shared.getProfileUser() {
            firstName = user.firstName
            lastName = user.lastName
            email = user.email
            roleLabel = user.roleLabel
        }
        if let tz = try? await APIClient.shared.getTimezones() { timezones = tz }
        if let prefs = try? await APIClient.shared.getPreferences() {
            currency = SettingsOptions.currencyValue(forStored: prefs.currency)
            timezone = prefs.timezone
            dateFormat = prefs.dateFormat
            language = prefs.language
            toggles = prefs.notifications
        }
        if let biz = try? await APIClient.shared.getBusinessProfile() {
            business = biz
            companyName = biz.businessName
        }
        loaded = true
    }

    func saveProfile() async {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty else { toast = "First name is required."; return }
        guard !mail.isEmpty else { toast = "Email is required."; return }
        guard mail.contains("@"), mail.contains(".") else { toast = "Enter a valid email."; return }
        savingProfile = true
        defer { savingProfile = false }
        do {
            try await APIClient.shared.updateProfile(
                firstName: first, lastName: lastName.trimmingCharacters(in: .whitespaces),
                email: mail, phone: phone.trimmingCharacters(in: .whitespaces))
            toast = "Profile updated successfully."
        } catch {
            toast = (error as? LocalizedError)?.errorDescription ?? "Failed to update profile."
        }
    }

    func savePreferences() async {
        savingPrefs = true
        defer { savingPrefs = false }
        do {
            try await APIClient.shared.updatePreferenceValues(
                language: language, currency: currency, timezone: timezone, dateFormat: dateFormat)
            toast = "Preferences updated successfully."
        } catch {
            toast = (error as? LocalizedError)?.errorDescription ?? "Failed to update preferences."
        }
    }

    func saveNotifications() async {
        savingNotifications = true
        defer { savingNotifications = false }
        let flags = Dictionary(uniqueKeysWithValues:
            SettingsOptions.toggleKeys.map { ($0, toggles[$0] ?? true) })
        do {
            try await APIClient.shared.updateNotifications(flags)
            toast = "Preferences updated successfully."
        } catch {
            toast = (error as? LocalizedError)?.errorDescription ?? "Failed to update preferences."
        }
    }

    func changePassword() async {
        guard !currentPassword.isEmpty else { toast = "Enter current password"; return }
        guard newPassword.count >= 8 else { toast = "Password must be at least 8 characters."; return }
        guard newPassword == confirmPassword else { toast = "Passwords do not match."; return }
        savingPassword = true
        defer { savingPassword = false }
        do {
            try await APIClient.shared.changePassword(
                currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""; newPassword = ""; confirmPassword = ""
            toast = "Password updated successfully."
        } catch {
            toast = (error as? LocalizedError)?.errorDescription ?? "Failed to update password."
        }
    }
}
