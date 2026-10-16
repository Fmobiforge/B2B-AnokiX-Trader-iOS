import SwiftUI

/// Airtime & VAS › Onboard customer. Registers an end-customer in the Limes CRM so an
/// account exists before a SIM is assigned. "View request body" previews the exact JSON the
/// server would POST to Limes without sending anything, which is how an operator checks a
/// half-filled form.
struct VasOnboardSection: View {
    @ObservedObject var store: VasStore

    // Label/value pairs for the Limes system codes. Labels are what the operator reads;
    // the value is what the API expects.
    private let titles = [("Mr", "Mr"), ("Mrs", "Mrs"), ("Ms", "Ms"), ("Dr", "Dr")]
    private let idTypes = [("ID", "SA ID"), ("PASSPORT", "Passport")]
    private let taxSchemes = [("VB8", "VB8 · VAT 15%")]
    private let plans = [("STD9", "STD9 · Standard")]
    private let languages = [("en-gb", "English"), ("af-za", "Afrikaans")]
    private let roles = [("CUSTOMER", "Customer")]
    private let media = [("EMAIL", "Email"), ("SMS", "SMS"), ("POST", "Post")]
    private let countries = [("South Africa", "South Africa")]

    @State private var title = "Mr"
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var idType = "ID"
    @State private var idNumber = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var taxScheme = "VB8"
    @State private var plan = "STD9"
    @State private var language = "en-gb"
    @State private var role = "CUSTOMER"
    @State private var billMedia = "EMAIL"
    @State private var country = "South Africa"
    @State private var streetNo = ""
    @State private var streetName = ""
    @State private var suburb = ""
    @State private var city = ""
    @State private var province = ""
    @State private var postCode = ""

    @State private var submitting = false
    @State private var previewing = false
    @State private var prefilled = false
    @State private var message: VasMessage?
    @State private var result: VasMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VasSectionHeader(
                title: "Onboard a customer",
                body_: "Register the customer with Limes so an account exists before you assign "
                     + "them a SIM & number. The system codes are pre-filled with the values the "
                     + "Limes API expects.")

            Text("**When do I need this?** Only when signing a customer up to a SIM / contract "
                 + "subscription — onboard them here, then activate their SIM on the "
                 + "**Subscription** tab. For airtime, data or bundle top-ups you don't need "
                 + "this: use **Catalog & orders** or **Dynamic services**, which provision "
                 + "straight to a phone number.")
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Brand.surfaceVariant)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            identityFields
            systemCodeFields
            addressFields
            actions
        }
        .card()
        .onAppear(perform: prefillFromSignedInUser)
        .sheet(item: $message) { VasMessageSheet(title: $0.title, message: $0.body) }
        .alert(result?.title ?? "", isPresented: resultBinding, presenting: result) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0.body) }
    }

    // MARK: Fields

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VasPicker(title: "Title", options: titles, selection: $title)
            HStack(spacing: 12) {
                VasField(title: "First name", text: $firstName, placeholder: "Tam")
                VasField(title: "Last name", text: $lastName, placeholder: "Ho")
            }
            VasPicker(title: "ID type", options: idTypes, selection: $idType)
            // A SA ID is 13 digits; a passport is alphanumeric — so the keyboard follows suit.
            VasField(title: "ID number", text: $idNumber,
                     placeholder: idType == "ID" ? "13 digits" : "Passport number",
                     keyboard: idType == "ID" ? .numberPad : .default,
                     autocapitalize: idType != "ID")
            VasField(title: "Email", text: $email, placeholder: "name@example.com",
                     keyboard: .emailAddress, autocapitalize: false)
            VasField(title: "Mobile number", text: $phone, placeholder: "27821234567",
                     keyboard: .phonePad, autocapitalize: false)
        }
    }

    private var systemCodeFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VasPicker(title: "Tax scheme", options: taxSchemes, selection: $taxScheme)
            VasPicker(title: "Collection plan", options: plans, selection: $plan)
            VasPicker(title: "Bill language", options: languages, selection: $language)
            VasPicker(title: "Contact role", options: roles, selection: $role)
            VasPicker(title: "Bill media", options: media, selection: $billMedia)
            VasPicker(title: "Country", options: countries, selection: $country)
        }
    }

    private var addressFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Billing address")
                .font(.app(14, .bold))
                .foregroundColor(Brand.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                VasField(title: "Street no.", text: $streetNo, placeholder: "12")
                VasField(title: "Street name", text: $streetName, placeholder: "Main Road")
            }
            HStack(spacing: 12) {
                VasField(title: "Suburb", text: $suburb, placeholder: "Claremont")
                VasField(title: "City", text: $city, placeholder: "Cape Town")
            }
            HStack(spacing: 12) {
                VasField(title: "Province", text: $province, placeholder: "Western Cape")
                VasField(title: "Postal code", text: $postCode, placeholder: "7708",
                         keyboard: .numberPad, autocapitalize: false)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(submitting ? "Processing…" : "Create customer") { submit() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(submitting)
                .opacity(submitting ? 0.6 : 1)

            Button(previewing ? "Building…" : "View request body") { preview() }
                .font(.app(14, .semibold))
                .foregroundColor(Brand.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .buttonStyle(.plain)
                .disabled(previewing)
        }
    }

    // MARK: Prefill

    /// Opens the form on the signed-in operator's own details, which is what the web portal
    /// does: most first onboards are the merchant registering themselves, and everything
    /// here stays editable for the customers that follow.
    ///
    /// The saved login carries the name and email; the mobile number is only known once the
    /// profile has been read, so a session without one falls back to a single profile call
    /// rather than leaving the field blank.
    private func prefillFromSignedInUser() {
        guard !prefilled else { return }
        prefilled = true

        if let user = LoginSessionStore.load()?.user {
            setIfEmpty(&firstName, user.first_name)
            setIfEmpty(&lastName, user.last_name)
            setIfEmpty(&email, user.email)
            setIfEmpty(&phone, user.phone_number)
        }
        guard phone.trimmed.isEmpty else { return }

        Task {
            // A prefill is a convenience — the operator can still type the details.
            guard let user = try? await APIClient.shared.getProfileUser() else { return }
            setIfEmpty(&firstName, user.firstName)
            setIfEmpty(&lastName, user.lastName)
            setIfEmpty(&email, user.email)
            setIfEmpty(&phone, user.phone)
        }
    }

    /// Writes `value` only into a field the operator has not typed into.
    private func setIfEmpty(_ field: inout String, _ value: String?) {
        guard let value = value?.trimmed, !value.isEmpty, field.trimmed.isEmpty else { return }
        field = value
    }

    // MARK: Request

    /// The onboard form as the flat field map both `onboard-customer` and its preview take.
    /// The optional passport fields are always sent blank — the server omits them.
    private func buildForm() -> [String: String] {
        [
            "title": title,
            "firstname": firstName.trimmed,
            "lastname": lastName.trimmed,
            "id_type": idType,
            "id_number": idNumber.trimmed,
            "id_issuer": "",
            "id_issued_date": "",
            "id_expiry_date": "",
            "email": email.trimmed,
            "tax_scheme": taxScheme,
            "collection_plan": plan,
            "bill_language": language,
            "contact_role": role,
            "bill_media": billMedia,
            "country": country,
            "phone": phone.trimmed,
            "street_no": streetNo.trimmed,
            "street_name": streetName.trimmed,
            "suburb": suburb.trimmed,
            "city": city.trimmed,
            "province": province.trimmed,
            "post_code": postCode.trimmed,
        ]
    }

    private func submit() {
        if let problem = validationProblem() {
            store.error = problem
            return
        }
        submitting = true
        Task {
            do {
                let data = try await APIClient.shared.onboardVasCustomer(form: buildForm())
                result = VasMessage(
                    title: "Customer created",
                    body: data.alreadyExists
                        ? "Limes already had this customer. Go straight to the Subscription "
                          + "tab to activate their SIM."
                        : "The customer is registered with Limes. Activate their SIM on the "
                          + "Subscription tab.")
                // The Customers tab and the Acting as picker must not show a stale list.
                store.invalidateCustomers()
            } catch {
                store.error = (error as? LocalizedError)?.errorDescription
                    ?? "Could not create the customer."
            }
            submitting = false
        }
    }

    /// The preview runs no validation on purpose — seeing a half-filled body is the point.
    private func preview() {
        previewing = true
        Task {
            do {
                let data = try await APIClient.shared.previewVasOnboard(form: buildForm())
                message = VasMessage(title: "Request body", body: data.rendered)
            } catch {
                store.error = (error as? LocalizedError)?.errorDescription
                    ?? "Could not build the request body."
            }
            previewing = false
        }
    }

    private func validationProblem() -> String? {
        if firstName.trimmed.isEmpty { return "Please enter the customer's first name." }
        if lastName.trimmed.isEmpty { return "Please enter the customer's last name." }
        if idNumber.trimmed.isEmpty { return "Please enter the customer's ID or passport number." }
        let mail = email.trimmed
        if mail.isEmpty || !mail.contains("@") || !mail.contains(".") {
            return "Please enter a valid email address."
        }
        if phone.trimmed.isEmpty { return "Please enter the recipient's mobile number." }
        if !VasFormat.isValidMsisdn(phone.trimmed) {
            return "Enter a valid mobile number, e.g. 082 123 4567."
        }
        return nil
    }

    private var resultBinding: Binding<Bool> {
        Binding(get: { result != nil }, set: { if !$0 { result = nil } })
    }
}
