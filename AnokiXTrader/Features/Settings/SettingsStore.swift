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
    // Currency — the API takes the ISO code ("ZAR"), which is also what we display.
    static let currencies = [
        SettingsOption(value: "ZAR", label: "ZAR"),
        SettingsOption(value: "USD", label: "USD"),
        SettingsOption(value: "EUR", label: "EUR"),
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

    /// Airtime & VAS payment — how VAS purchases are settled.
    static let vasPaymentModes = [
        SettingsOption(value: "wallet", label: "anokiX wallet (debit on purchase)"),
        SettingsOption(value: "direct", label: "Direct settlement with Limes"),
    ]

    /// Notification toggles — keys/titles/descriptions + order verbatim from the web
    /// portal's Notification Preferences screen.
    static let toggles = [
        NotifToggle(key: "orderAlerts", title: "Order Alerts",
                    desc: "Get notified about your order status changes."),
        NotifToggle(key: "deliveryUpdates", title: "Delivery Updates",
                    desc: "Track delivery status changes and delays."),
        NotifToggle(key: "promotionAlerts", title: "Promotion Alerts",
                    desc: "Hear about new deals and promotions from distributors."),
        NotifToggle(key: "financeReminders", title: "Finance Reminders",
                    desc: "Reminders for overdue invoices and payments."),
        NotifToggle(key: "reportReady", title: "Report Ready",
                    desc: "Notify when scheduled reports are generated."),
    ]
    static var toggleKeys: [String] { toggles.map(\.key) }

    /// Map a stored currency to its option value. Accepts the ISO code and also the
    /// legacy numeric ids the backend used to store, so an account saved before the
    /// switch still resolves to the right option.
    static func currencyValue(forStored stored: String) -> String {
        let code = stored.uppercased()
        if currencies.contains(where: { $0.value == code }) { return code }
        let legacyIds = ["1": "ZAR", "2": "USD", "3": "EUR"]
        return legacyIds[stored] ?? "ZAR"
    }
}

// MARK: - DTOs

struct ProfileUser {
    var firstName: String, lastName: String, email: String, roleLabel: String, phone: String
    init(json: JSON) {
        firstName = json["first_name"].stringValue
        lastName = json["last_name"].stringValue
        email = json["email"].stringValue
        // base-info may carry the user's phone (the Distributor app reads the same field);
        // absent → "" so the field just stays empty.
        phone = json["phone_number"].stringValue
        let role = json["role_label"].string
        roleLabel = (role?.isEmpty == false) ? role! : "Trader"
    }
}

struct PreferencesDTO {
    var language: String, currency: String, timezone: String, dateFormat: String
    /// How Airtime & VAS purchases are paid for: "wallet" or "direct".
    var vasPaymentMode: String
    var notifications: [String: Bool]   // resolved per known key (missing/array => ON)
    init(json: JSON) {
        language = json["language"].string ?? "en"
        currency = json["currency"].string ?? "ZAR"
        timezone = json["timezone"].string ?? "Africa/Johannesburg"
        dateFormat = json["date_format"].string ?? "DD MMM YYYY"
        vasPaymentMode = json["vas_payment_mode"].string ?? "wallet"
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

    // Editor prefill fields (mirrors the Android `loadProfile`).
    var traderType: String, paymentMethod: String
    var primaryCategoryIds: String, preferredDistributorIds: String, preferredDeliveryDays: String
    var latitude: Double?, longitude: Double?
    var companyLogoUrl: String?
    /// POST field key → existing uploaded file name (for the Verify step "Uploaded"/"Replace" state).
    var uploadedDocNames: [String: String]

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
        traderType = json["trader_type"].optStringFlexible
        paymentMethod = json["payment_method"].stringValue
        primaryCategoryIds = json["primary_product_category_ids"].optStringFlexible
        preferredDistributorIds = json["preferred_distributor_ids"].optStringFlexible
        preferredDeliveryDays = json["preferred_delivery_days"].stringValue
        latitude = json["latitude"].double
        longitude = json["longitude"].double
        let logo = json["company_logo_url"].string ?? json["company_logo"].string
        companyLogoUrl = (logo?.isEmpty == false) ? logo : nil

        let d = json["documents"]
        // GET key → (POST field key, display label). The Verify step posts under the POST keys.
        let mapping: [(getKey: String, field: String, label: String)] = [
            ("registration_document", "business_registration_document", "Business Registration Document"),
            ("id_document", "owner_id_document", "Owner ID Document"),
            ("proof_of_address", "proof_of_address", "Proof of Address"),
            ("store_front_photo", "store_front_photo", "Store Front Photo"),
            ("store_interior_photo", "store_interior_photo", "Store Interior Photo"),
            ("additional_document", "additional_documents", "Additional Documents"),
        ]
        documents = mapping.map { m in
            BusinessDocGroup(label: m.label, docs: (d[m.getKey].array ?? []).map(BusinessDoc.init(json:)))
        }
        var names: [String: String] = [:]
        for m in mapping {
            if let first = d[m.getKey].array?.first {
                names[m.field] = first["original_name"].string ?? "file"
            }
        }
        uploadedDocNames = names
    }
}

private extension JSON {
    /// A scalar that may arrive as a string ("3") or a number (3); "" when absent/null.
    var optStringFlexible: String {
        if let s = string { return s }
        if type == .number { return stringValue }
        return ""
    }
}

// MARK: - Store

@MainActor
final class SettingsStore: ObservableObject {
    // Profile
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""                        // national digits (dial code prepended on save)
    @Published var phoneCountry = Countries.default
    @Published var roleLabel = "Trader"
    @Published var companyName = ""

    // Preferences (values are what the API expects)
    @Published var currency = "ZAR"
    @Published var timezone = "Africa/Johannesburg"
    @Published var dateFormat = "DD MMM YYYY"
    @Published var language = "en"
    @Published var vasPaymentMode = "wallet"
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
            let (country, national) = PhoneCompose.split(user.phone)
            phoneCountry = country
            phone = national
        }
        if let tz = try? await APIClient.shared.getTimezones() { timezones = tz }
        if let prefs = try? await APIClient.shared.getPreferences() {
            currency = SettingsOptions.currencyValue(forStored: prefs.currency)
            timezone = prefs.timezone
            dateFormat = prefs.dateFormat
            language = prefs.language
            vasPaymentMode = prefs.vasPaymentMode
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
                email: mail, phone: PhoneCompose.full(country: phoneCountry, national: phone))
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
                language: language, currency: currency, timezone: timezone,
                dateFormat: dateFormat, vasPaymentMode: vasPaymentMode)
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

// MARK: - Business Profile editor store

/// Drives the 7-step Business Profile editor (Owner · Business · Type · Location ·
/// Verify · Distributor · Wallet). Prefills from `getBusinessProfile` + `getReference`
/// and saves each step's own subset to `api/trader/business/profile/update` (partial
/// multipart). 1:1 with the Android `BusinessProfileActivity`.
@MainActor
final class BusinessEditStore: ObservableObject {
    // Step 0 — Owner
    @Published var idNumber = ""
    @Published var passportNumber = ""

    // Step 1 — Business
    @Published var logo: UIImage?
    @Published var existingLogoUrl: String?
    @Published var businessName = ""
    @Published var tradingName = ""
    @Published var businessRegNumber = ""
    @Published var businessEmail = ""
    @Published var businessPhone = ""                       // national digits
    @Published var businessPhoneCountry = Countries.default

    // Step 2 — Type
    @Published var traderTypeId: Int?
    @Published var selectedCategoryIds: Set<Int> = []

    // Step 3 — Location
    @Published var address = ""
    @Published var latitude: Double?
    @Published var longitude: Double?

    // Step 4 — Verify (POST field key -> newly picked document)
    @Published var documents: [String: RegDocument] = [:]
    @Published var uploadedDocNames: [String: String] = [:]  // already on file

    // Step 5 — Distributor
    @Published var selectedDistributorIds: Set<Int> = []
    @Published var deliveryRows: [DeliveryRow] = DeliveryGrid.makeRows()
    @Published var paymentMethod = ""

    // Reference data
    @Published var traderTypes: [TraderTypeDTO] = []
    @Published var categories: [ProductCategoryDTO] = []
    @Published var distributors: [DistributorRefDTO] = []

    // UI state
    @Published var loaded = false
    @Published var saving = false
    @Published var toast: String?

    private var profileLoaded = false
    private var referenceLoaded = false
    private var pendingCategoryIds: [Int] = []
    private var pendingDistributorIds: [Int] = []

    /// Verify-step document rows (POST field key, title) — order matches Android `docDefs`.
    static let verifyDocs: [(field: String, label: String)] = [
        ("business_registration_document", "Business Registration Document"),
        ("owner_id_document", "Owner ID Document"),
        ("proof_of_address", "Proof of Address"),
        ("store_front_photo", "Store Front Photo"),
        ("store_interior_photo", "Store Interior Photo"),
    ]

    var parentCategories: [ProductCategoryDTO] { categories.filter { $0.parent_id == nil } }
    var traderTypeName: String { traderTypes.first { $0.id == traderTypeId }?.name ?? "" }
    var paymentLabel: String { RegisterStore.paymentOptions.first { $0.code == paymentMethod }?.label ?? "" }

    // MARK: Load

    func load() async {
        await loadReference()
        await loadProfile()
        loaded = true
    }

    private func loadReference() async {
        do {
            let ref = try await APIClient.shared.getReference()
            traderTypes = (ref.trader_types?.isEmpty == false) ? ref.trader_types! : RegisterStore.fallbackTraderTypes
            categories = ref.product_categories ?? []
            distributors = ref.distributors ?? []
        } catch {
            traderTypes = RegisterStore.fallbackTraderTypes
        }
        referenceLoaded = true
        applyPendingSelections()
    }

    private func loadProfile() async {
        guard let p = try? await APIClient.shared.getBusinessProfile() else { return }
        idNumber = p.idNumber
        passportNumber = p.passportNumber
        businessName = p.businessName
        tradingName = p.tradingName
        businessRegNumber = p.registrationNumber
        businessEmail = p.businessEmail
        let (country, national) = PhoneCompose.split(p.businessPhone)
        businessPhoneCountry = country
        businessPhone = national
        existingLogoUrl = p.companyLogoUrl
        traderTypeId = Int(p.traderType)
        address = p.address
        latitude = p.latitude
        longitude = p.longitude
        uploadedDocNames = p.uploadedDocNames
        paymentMethod = p.paymentMethod
        var rows = deliveryRows
        DeliveryGrid.apply(p.preferredDeliveryDays, to: &rows)
        deliveryRows = rows
        pendingCategoryIds = Self.parseIds(p.primaryCategoryIds)
        pendingDistributorIds = Self.parseIds(p.preferredDistributorIds)
        profileLoaded = true
        applyPendingSelections()
    }

    /// Categories/distributors can only resolve once BOTH the profile (selected ids) and
    /// the reference list have loaded — mirrors Android `applyPrefillSelections`.
    private func applyPendingSelections() {
        guard profileLoaded, referenceLoaded else { return }
        selectedCategoryIds = Set(pendingCategoryIds)
        selectedDistributorIds = Set(pendingDistributorIds)
    }

    static func parseIds(_ csv: String) -> [Int] {
        csv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: Save (per step)

    func saveStep(_ step: Int) async {
        var fields: [String: String] = [:]
        var files: [MultipartFile] = []
        switch step {
        case 0:
            fields["id_number"] = idNumber.trimmed
            fields["passport_number"] = passportNumber.trimmed
        case 1:
            guard !businessName.trimmed.isEmpty else { toast = "Business name is required."; return }
            fields["business_name"] = businessName.trimmed
            fields["trading_name"] = tradingName.trimmed
            fields["business_registration_number"] = businessRegNumber.trimmed
            fields["business_email"] = businessEmail.trimmed
            fields["business_phone_number"] = PhoneCompose.full(country: businessPhoneCountry, national: businessPhone)
            if let logo, let data = logo.downscaledJPEG(maxDimension: 600, quality: 0.85) {
                files.append(MultipartFile(field: "company_logo", fileName: "company_logo.jpg",
                                           mimeType: "image/jpeg", data: data))
            }
        case 2:
            guard let t = traderTypeId else { toast = "Select a trader type."; return }
            fields["trader_type"] = String(t)
            fields["primary_product_category_ids"] =
                selectedCategoryIds.sorted().map(String.init).joined(separator: ",")
        case 3:
            fields["address"] = address.trimmed
            if let lat = latitude, let lng = longitude {
                fields["latitude"] = String(lat)
                fields["longitude"] = String(lng)
            }
        case 4:
            for (field, doc) in documents {
                files.append(MultipartFile(field: field, fileName: doc.fileName,
                                           mimeType: doc.mimeType, data: doc.data))
            }
            guard !files.isEmpty else { toast = "Pick a document to upload first."; return }
        case 5:
            fields["preferred_distributor_ids"] =
                selectedDistributorIds.sorted().map(String.init).joined(separator: ",")
            fields["preferred_delivery_days"] = DeliveryGrid.serialize(deliveryRows)
            fields["payment_method"] = paymentMethod
        default:
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await APIClient.shared.updateBusinessProfile(fields: fields, files: files)
            if step == 4 {
                // Reflect freshly-uploaded docs as on-file.
                for (field, doc) in documents { uploadedDocNames[field] = doc.fileName }
                documents.removeAll()
            }
            toast = "Business profile updated."
        } catch {
            toast = (error as? LocalizedError)?.errorDescription ?? "Failed to update business profile."
        }
    }
}
