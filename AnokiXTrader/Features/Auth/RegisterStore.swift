import SwiftUI
import UIKit

/// A KYC document selected for upload (image or PDF) in the Create Account flow.
struct RegDocument: Hashable {
    let fileName: String
    let mimeType: String
    let data: Data
}

/// Holds all state for the 8-step trader Create Account wizard and submits it to
/// `api/trader/register` using the same real-payload field names as Android.
final class RegisterStore: ObservableObject {

    // Step 1 — owner
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var idNumber = ""
    @Published var passportNumber = ""
    @Published var mobile = ""            // national digits (country dial code prepended on submit)
    @Published var mobileCountry = Countries.default
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    // Step 2 — business
    @Published var logo: UIImage?
    @Published var businessName = ""
    @Published var tradingName = ""
    @Published var businessRegNumber = ""
    @Published var businessPhone = ""
    @Published var businessPhoneCountry = Countries.default
    @Published var businessEmail = ""

    // Step 3 — classification
    @Published var traderTypeId: Int?
    @Published var selectedCategoryIds: Set<Int> = []

    // Step 4 — location
    @Published var address = ""
    @Published var placeId = ""
    @Published var latitude: Double?
    @Published var longitude: Double?

    // Step 5 — documents (field name -> document)
    @Published var documents: [String: RegDocument] = [:]

    // Step 6 — distributors / delivery / payment
    @Published var selectedDistributorIds: Set<Int> = []
    @Published var deliveryRows: [DeliveryRow] = {
        var rows = DeliveryGrid.makeRows()
        for i in [1, 3, 5] { rows[i].checked = true }   // Mon/Wed/Fri default on (0=Sun..6=Sat)
        return rows
    }()
    @Published var paymentMethod = "wallet"

    // Step 7 — wallet
    @Published var createWallet = true
    @Published var walletIdType = ""          // "ID" / "passport" / "asylum"
    @Published var walletIdNumber = ""
    @Published var walletPassportCountry = ""
    @Published var walletPassportExpDate: Date?
    @Published var walletDob: Date?           // manual DOB (passport / asylum)
    @Published var walletGenderManual = ""    // manual gender (passport / asylum)
    @Published var walletStreet = ""
    @Published var walletSuburb = ""
    @Published var walletCity = ""
    @Published var walletProvinceCode = ""    // ISO 3166-2:ZA code, e.g. "ZA-FS"
    @Published var walletPostCode = ""
    @Published var walletUssd = true
    @Published var walletInternet = true
    @Published var walletCrossBorder = false

    // Step 8 — terms
    @Published var termAccurate = false
    @Published var termTos = false
    @Published var termKyc = false
    @Published var termComms = false

    // Reference data
    @Published var traderTypes: [TraderTypeDTO] = []
    @Published var categories: [ProductCategoryDTO] = []
    @Published var distributors: [DistributorRefDTO] = []

    // Submit state
    @Published var submitting = false

    static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    // Labels + codes match the Android trader app (PAYMENT_LABELS / PAYMENT_CODES).
    static let paymentOptions: [(code: String, label: String)] = [
        ("wallet", "Wallet"), ("eft", "EFT"), ("cash", "Cash"), ("card", "Card")
    ]
    static let requiredDocs: [(field: String, label: String, sub: String)] = [
        ("business_registration_document", "Business Registration Document", "CIPC, Business Permit, etc."),
        ("owner_id_document", "Owner ID Document", "ID or Passport"),
        ("proof_of_address", "Proof of Address", "Municipal bill, Lease, etc."),
        ("store_front_photo", "Store Front Photo", "Clear photo of your store"),
        ("store_interior_photo", "Store Interior Photo", "Inside view of your store")
    ]

    // Wallet › ID types, genders, provinces (labels + payload codes; match Android).
    static let idTypeOptions: [(code: String, label: String)] = [
        ("ID", "SA ID Number"), ("passport", "Passport"), ("asylum", "Asylum Document")
    ]
    static let genderOptions = ["Male", "Female", "Other"]
    static let provinceOptions: [(code: String, label: String)] = [
        ("ZA-EC", "Eastern Cape"), ("ZA-FS", "Free State"), ("ZA-GP", "Gauteng"),
        ("ZA-LP", "Limpopo"), ("ZA-MP", "Mpumalanga"), ("ZA-NC", "Northern Cape"),
        ("ZA-KZN", "Kwa-Zulu Natal"), ("ZA-NW", "North West"), ("ZA-WC", "Western Cape")
    ]

    /// yyyy-MM-dd formatter for the wallet DOB / passport-expiry payload fields.
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var walletIdTypeLabel: String {
        RegisterStore.idTypeOptions.first(where: { $0.code == walletIdType })?.label ?? ""
    }
    var walletProvinceLabel: String {
        RegisterStore.provinceOptions.first(where: { $0.code == walletProvinceCode })?.label ?? ""
    }

    // MARK: - South African ID validation

    enum SAIDStatus: Equatable {
        case empty
        case invalidLength
        case invalidDate
        case invalidChecksum
        case valid(dob: Date, gender: String)
    }

    /// Parses `walletIdNumber` as a South African ID (YYMMDDSSSSCAZ).
    func saIdStatus() -> SAIDStatus {
        let id = walletIdNumber.trimmed
        if id.isEmpty { return .empty }
        if id.count != 13 || !id.allSatisfy({ $0.isNumber }) { return .invalidLength }

        let yy = Int(id.prefix(2))!
        let mm = Int(id.dropFirst(2).prefix(2))!
        let dd = Int(id.dropFirst(4).prefix(2))!
        guard mm >= 1, mm <= 12, dd >= 1, dd <= 31 else { return .invalidDate }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let currentYy = cal.component(.year, from: Date()) % 100
        let year = yy > currentYy ? 1900 + yy : 2000 + yy
        var comps = DateComponents()
        comps.year = year; comps.month = mm; comps.day = dd
        guard let dob = cal.date(from: comps),
              cal.component(.day, from: dob) == dd,
              cal.component(.month, from: dob) == mm else { return .invalidDate }

        if !RegisterStore.luhnValid(id) { return .invalidChecksum }

        let seq = Int(id.dropFirst(6).prefix(4))!
        let gender = seq >= 5000 ? "Male" : "Female"
        return .valid(dob: dob, gender: gender)
    }

    static func luhnValid(_ num: String) -> Bool {
        var sum = 0
        var doubleDigit = false
        for ch in num.reversed() {
            guard let d0 = ch.wholeNumberValue else { return false }
            var d = d0
            if doubleDigit { d *= 2; if d > 9 { d -= 9 } }
            sum += d
            doubleDigit.toggle()
        }
        return sum % 10 == 0
    }

    /// Effective DOB / gender: derived from the ID when SA-ID, otherwise the manual entry.
    var effectiveDob: Date? {
        if walletIdType == "ID" {
            if case .valid(let dob, _) = saIdStatus() { return dob }
            return nil
        }
        return walletDob
    }
    var effectiveGender: String {
        if walletIdType == "ID" {
            if case .valid(_, let g) = saIdStatus() { return g }
            return ""
        }
        return walletGenderManual
    }

    /// Fallback trader types mirroring the Android design names (ids 1–8).
    static let fallbackTraderTypes: [TraderTypeDTO] = [
        TraderTypeDTO(id: 1, name: "Spaza Shop", slug: nil, icon: nil, sort_order: 1),
        TraderTypeDTO(id: 2, name: "Mini Market", slug: nil, icon: nil, sort_order: 2),
        TraderTypeDTO(id: 3, name: "Superette", slug: nil, icon: nil, sort_order: 3),
        TraderTypeDTO(id: 4, name: "General Dealer", slug: nil, icon: nil, sort_order: 4),
        TraderTypeDTO(id: 5, name: "Wholesaler", slug: nil, icon: nil, sort_order: 5),
        TraderTypeDTO(id: 6, name: "Pharmacy", slug: nil, icon: nil, sort_order: 6),
        TraderTypeDTO(id: 7, name: "Butchery", slug: nil, icon: nil, sort_order: 7),
        TraderTypeDTO(id: 8, name: "Restaurant", slug: nil, icon: nil, sort_order: 8)
    ]

    var parentCategories: [ProductCategoryDTO] {
        categories.filter { $0.parent_id == nil }
    }

    var traderTypeName: String {
        traderTypes.first(where: { $0.id == traderTypeId })?.name ?? ""
    }

    var paymentLabel: String {
        RegisterStore.paymentOptions.first(where: { $0.code == paymentMethod })?.label ?? ""
    }

    // MARK: - Reference loading

    func loadReference() async {
        do {
            let ref = try await APIClient.shared.getReference()
            let types = (ref.trader_types?.isEmpty == false) ? ref.trader_types! : RegisterStore.fallbackTraderTypes
            let cats = ref.product_categories ?? []
            let dists = ref.distributors ?? []
            await MainActor.run {
                traderTypes = types
                categories = cats
                distributors = dists
            }
        } catch {
            await MainActor.run { traderTypes = RegisterStore.fallbackTraderTypes }
        }
    }

    // MARK: - Validation (returns an error string or nil)

    func validate(step: Int) -> String? {
        switch step {
        case 0:
            if firstName.trimmed.isEmpty { return "Please enter your first name." }
            if lastName.trimmed.isEmpty { return "Please enter your last name." }
            if idNumber.trimmed.isEmpty && passportNumber.trimmed.isEmpty {
                return "Enter an ID number or passport number."
            }
            if mobile.trimmed.count < 9 { return "Please enter a valid mobile number." }
            if !email.contains("@") { return "Please enter a valid email." }
            if password.count < 8 { return "Password must be at least 8 characters." }
            if password != confirmPassword { return "Passwords do not match." }
        case 1:
            if businessName.trimmed.isEmpty { return "Please enter the business name." }
            if !businessEmail.isEmpty && !businessEmail.contains("@") {
                return "Please enter a valid business email."
            }
        case 2:
            if traderTypeId == nil { return "Please select a trader type." }
            if selectedCategoryIds.isEmpty { return "Select at least one product category." }
        case 3:
            if address.trimmed.isEmpty { return "Please choose your business location." }
        case 4:
            for doc in RegisterStore.requiredDocs where documents[doc.field] == nil {
                return "Please upload: \(doc.label)."
            }
        case 5:
            if selectedDistributorIds.isEmpty { return "Select at least one distributor." }
            if !deliveryRows.contains(where: { $0.checked }) { return "Choose at least one delivery day." }
            if paymentMethod.isEmpty { return "Select a payment method." }
        case 6:
            return validateWallet()
        case 7:
            if !(termAccurate && termTos && termKyc && termComms) {
                return "Please accept all terms to continue."
            }
        default:
            break
        }
        return nil
    }

    /// Wallet step: nothing required when "Activate Later"; full identity + address otherwise.
    private func validateWallet() -> String? {
        if !createWallet { return nil }
        if walletIdType.isEmpty { return "Please choose an ID type." }
        if walletIdNumber.trimmed.isEmpty { return "Please enter the owner's ID / document number." }
        if walletIdType == "ID" {
            if case .valid = saIdStatus() {} else {
                return "Please enter a valid 13-digit South African ID number."
            }
        }
        if walletIdType == "passport" {
            if walletPassportCountry.trimmed.isEmpty { return "Please enter the passport country." }
            if walletPassportExpDate == nil { return "Please select the passport expiry date." }
        }
        if effectiveDob == nil { return "Please select the date of birth." }
        if effectiveGender.isEmpty { return "Please select a gender." }
        if walletStreet.trimmed.isEmpty { return "Please enter the street address." }
        if walletSuburb.trimmed.isEmpty { return "Please enter the suburb." }
        if walletCity.trimmed.isEmpty { return "Please enter the city." }
        if walletProvinceCode.isEmpty { return "Please select a province." }
        if walletPostCode.trimmed.isEmpty { return "Please enter the postal code." }
        return nil
    }

    // MARK: - Submit

    var fullMobile: String { fullPhone(country: mobileCountry, raw: mobile) }
    var fullBusinessPhone: String { fullPhone(country: businessPhoneCountry, raw: businessPhone) }

    /// Country dial code (digits only) + national number, leading 0 dropped, no '+'
    /// — matches the Android `ccp.getFullNumber()` format (e.g. "27821234567").
    private func fullPhone(country: Country, raw: String) -> String {
        var digits = raw.filter { $0.isNumber }
        if digits.isEmpty { return "" }
        if digits.hasPrefix("0") { digits = String(digits.dropFirst()) }
        let code = country.dialDigits
        if digits.hasPrefix(code) { return digits }
        return code + digits
    }

    func submit() async throws {
        await MainActor.run { submitting = true }

        var fields: [String: String] = [
            "first_name": firstName.trimmed,
            "last_name": lastName.trimmed,
            "mobile_number": fullMobile,
            "email": email.trimmed,
            "password": password,
            "id_number": idNumber.trimmed,
            "passport_number": passportNumber.trimmed,
            "business_name": businessName.trimmed,
            "trading_name": tradingName.trimmed,
            "business_registration_number": businessRegNumber.trimmed,
            "business_phone_number": fullBusinessPhone,
            "business_email": businessEmail.trimmed,
            "trader_type": traderTypeId.map(String.init) ?? "",
            "primary_product_category_ids": selectedCategoryIds.sorted().map(String.init).joined(separator: ","),
            "address": address.trimmed,
            "latitude": latitude.map { String($0) } ?? "",
            "longitude": longitude.map { String($0) } ?? "",
            "preferred_distributor_ids": selectedDistributorIds.sorted().map(String.init).joined(separator: ","),
            "preferred_delivery_days": DeliveryGrid.selectedDaysCSV(deliveryRows),
            "payment_method": paymentMethod
        ]
        if let firstDist = selectedDistributorIds.sorted().first {
            fields["recommended_distributor"] = String(firstDist)
        }

        // ---- Wallet ----
        fields["wallet_activation"] = createWallet ? "now" : "later"
        if createWallet {
            fields["wallet_id_type"] = walletIdType
            fields["wallet_id_number"] = walletIdNumber.trimmed
            if walletIdType == "passport" {
                fields["wallet_passport_country"] = walletPassportCountry.trimmed
                if let exp = walletPassportExpDate {
                    fields["wallet_passport_exp_date"] = RegisterStore.isoDate.string(from: exp)
                }
            }
            if let dob = effectiveDob {
                fields["wallet_dob"] = RegisterStore.isoDate.string(from: dob)
            }
            fields["wallet_gender"] = effectiveGender
            fields["wallet_street_address"] = walletStreet.trimmed
            fields["wallet_suburb"] = walletSuburb.trimmed
            fields["wallet_city"] = walletCity.trimmed
            fields["wallet_province"] = walletProvinceCode
            fields["wallet_post_code"] = walletPostCode.trimmed
            fields["wallet_ussd"] = walletUssd ? "1" : "0"
            fields["wallet_internet"] = walletInternet ? "1" : "0"
            fields["wallet_cross_border"] = walletCrossBorder ? "1" : "0"
        }

        var files: [MultipartFile] = []
        // JPEG (not PNG) and downscaled — a full-size PNG logo alone can be several MB.
        if let logo, let data = logo.downscaledJPEG(maxDimension: 600, quality: 0.85) {
            files.append(MultipartFile(field: "company_logo", fileName: "company_logo.jpg",
                                       mimeType: "image/jpeg", data: data))
        }
        for (field, doc) in documents {
            files.append(MultipartFile(field: field, fileName: doc.fileName,
                                       mimeType: doc.mimeType, data: doc.data))
        }

        do {
            try await APIClient.shared.registerTrader(fields: fields, files: files)
            await MainActor.run { submitting = false }
        } catch {
            await MainActor.run { submitting = false }
            throw error
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
