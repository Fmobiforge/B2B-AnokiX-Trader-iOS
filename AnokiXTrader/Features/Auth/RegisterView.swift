import SwiftUI
import UIKit
import MapKit
import UniformTypeIdentifiers

struct RegisterView: View {
    @EnvironmentObject var session: Session
    @StateObject private var store = RegisterStore()

    @State private var step = 0
    @State private var error: String?
    @State private var submitted = false

    private let stepTitles = [
        "Owner Information", "Business Information", "Trader Classification",
        "Business Location", "Verification Documents", "Distributors & Delivery",
        "anokiX Wallet", "Terms & Conditions"
    ]

    var body: some View {
        if submitted {
            RegisterCompletedView { session.stage = .login }
        } else {
            wizard
                .task { await store.loadReference() }
        }
    }

    private var wizard: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(stepTitles[step])
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Brand.textPrimary)
                    stepContent
                }
                .padding(16)
            }
            footer
        }
        .background(Brand.background.ignoresSafeArea())
        .alert("Please check", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    if step == 0 { session.stage = .welcome } else { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("Create Account").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button { session.stage = .welcome } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                }
            }
            StepBar(count: 8, current: step).padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark],
                                   startPoint: .leading, endPoint: .trailing))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Brand.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.purple, lineWidth: 1))
            }
            Button(action: advance) {
                if store.submitting {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(step == 7 ? "Submit Application" : "Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.submitting)
        }
        .padding(16)
        .background(Brand.surface)
    }

    private func advance() {
        if let err = store.validate(step: step) { error = err; return }
        if step < 7 { step += 1; return }
        Task {
            do {
                try await store.submit()
                await MainActor.run { submitted = true }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "Submission failed."
                await MainActor.run { self.error = msg }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: OwnerStep(store: store)
        case 1: BusinessStep(store: store)
        case 2: ClassificationStep(store: store)
        case 3: LocationStep(store: store)
        case 4: DocumentsStep(store: store)
        case 5: DistributorsStep(store: store)
        case 6: WalletStep(store: store)
        default: TermsStep(store: store)
        }
    }
}

// MARK: - Step 1: Owner

private struct OwnerStep: View {
    @ObservedObject var store: RegisterStore
    var body: some View {
        VStack(spacing: 14) {
            LabeledField(title: "First Name", text: $store.firstName, placeholder: "John")
            LabeledField(title: "Last Name", text: $store.lastName, placeholder: "Doe")
            LabeledField(title: "ID Number", text: $store.idNumber, placeholder: "South African ID")
            LabeledField(title: "Passport Number (if no ID)", text: $store.passportNumber, placeholder: "Passport")
            HStack(spacing: 8) {
                Text("+27").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .padding(.vertical, 14).padding(.horizontal, 12)
                    .background(Brand.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 22)
                LabeledField(title: "Mobile Number", text: $store.mobile,
                             placeholder: "82 123 4567", keyboard: .phonePad)
            }
            LabeledField(title: "Email", text: $store.email, placeholder: "you@business.co.za",
                         keyboard: .emailAddress, autocap: .never, disableAutocorrect: true)
            LabeledSecureField(title: "Password", text: $store.password)
            LabeledSecureField(title: "Confirm Password", text: $store.confirmPassword)
        }
    }
}

// MARK: - Step 2: Business

private struct BusinessStep: View {
    @ObservedObject var store: RegisterStore
    @State private var source: UIImagePickerController.SourceType?
    @State private var showSourceDialog = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Company Logo (optional)").font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                Button { showSourceDialog = true } label: {
                    if let logo = store.logo {
                        Image(uiImage: logo).resizable().scaledToFill()
                            .frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "camera").font(.system(size: 22)).foregroundColor(Brand.purple)
                            Text("Upload Logo").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                        .frame(width: 96, height: 96)
                        .background(Brand.purpleLight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .buttonStyle(.plain)
            }
            LabeledField(title: "Business Name", text: $store.businessName, placeholder: "Registered name")
            LabeledField(title: "Trading Name", text: $store.tradingName, placeholder: "Shop name")
            LabeledField(title: "Business Registration Number (optional)", text: $store.businessRegNumber,
                         placeholder: "2023/123456/07")
            HStack(spacing: 8) {
                Text("+27").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .padding(.vertical, 14).padding(.horizontal, 12)
                    .background(Brand.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 22)
                LabeledField(title: "Business Phone", text: $store.businessPhone,
                             placeholder: "11 234 5678", keyboard: .phonePad)
            }
            LabeledField(title: "Business Email", text: $store.businessEmail,
                         placeholder: "info@business.co.za", keyboard: .emailAddress,
                         autocap: .never, disableAutocorrect: true)
        }
        .confirmationDialog("Choose image source", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { source = .camera }
            }
            Button("Photo Library") { source = .photoLibrary }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(get: { source.map { SourceWrap(type: $0) } },
                             set: { source = $0?.type })) { wrap in
            ImagePicker(sourceType: wrap.type, allowsEditing: true) { img in store.logo = img }
        }
    }
}

/// Identifiable wrapper so a UIImagePickerController.SourceType can drive `.sheet(item:)`.
struct SourceWrap: Identifiable {
    let type: UIImagePickerController.SourceType
    var id: Int { type.rawValue }
}

// MARK: - Step 3: Classification

private struct ClassificationStep: View {
    @ObservedObject var store: RegisterStore
    @State private var showTypes = false
    @State private var showCategories = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DropdownField(title: "Trader Type", value: store.traderTypeName,
                          placeholder: "Select trader type") { showTypes = true }

            VStack(alignment: .leading, spacing: 8) {
                DropdownField(title: "Primary Product Categories",
                              value: store.selectedCategoryIds.isEmpty ? "" :
                                "\(store.selectedCategoryIds.count) selected",
                              placeholder: "Select categories") { showCategories = true }
                if !store.selectedCategoryIds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.parentCategories.filter { store.selectedCategoryIds.contains($0.id) }) { c in
                                RemovableChip(label: c.title) { store.selectedCategoryIds.remove(c.id) }
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Trader Type", isPresented: $showTypes, titleVisibility: .visible) {
            ForEach(store.traderTypes) { t in
                Button(t.name) { store.traderTypeId = t.id }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCategories) {
            MultiSelectSheet(title: "Product Categories",
                             options: store.parentCategories.map { ($0.id, $0.title) },
                             selected: $store.selectedCategoryIds)
        }
    }
}

// MARK: - Step 4: Location

private struct LocationStep: View {
    @ObservedObject var store: RegisterStore
    @State private var query = ""
    @State private var suggestions: [AddressSuggestion] = []
    @State private var searching = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))

    private var pins: [LocationPin] {
        guard let lat = store.latitude, let lng = store.longitude else { return [] }
        return [LocationPin(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search for your business address").font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            HStack {
                TextField("Start typing your address…", text: $query)
                    .font(.system(size: 15)).foregroundColor(Brand.textPrimary)
                    .onChange(of: query) { _ in search() }
                if searching { ProgressView() }
            }
            .padding(14).background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { s in
                        Button { resolve(s) } label: {
                            HStack {
                                Image(systemName: "mappin.circle").foregroundColor(Brand.purple)
                                Text(s.description).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10).padding(.horizontal, 12)
                        }
                        Divider()
                    }
                }
                .background(Brand.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            }

            if !store.address.isEmpty {
                Text(store.address).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            }

            Map(coordinateRegion: $region, annotationItems: pins) { pin in
                MapMarker(coordinate: pin.coordinate, tint: Brand.purple)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func search() {
        guard query.count >= 3 else { suggestions = []; return }
        searching = true
        Task {
            let result = (try? await APIClient.shared.addressAutocomplete(query)) ?? []
            await MainActor.run { suggestions = result; searching = false }
        }
    }

    private func resolve(_ s: AddressSuggestion) {
        store.address = s.description
        query = s.description
        suggestions = []
        Task {
            if let coord = try? await APIClient.shared.coordinate(placeId: s.place_id) {
                await MainActor.run {
                    store.placeId = s.place_id
                    store.latitude = coord.lat
                    store.longitude = coord.lng
                    if let a = coord.resolvedAddress { store.address = a }
                    if let lat = coord.lat, let lng = coord.lng {
                        region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    }
                }
            }
        }
    }
}

struct LocationPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Step 5: Documents

private struct DocumentsStep: View {
    @ObservedObject var store: RegisterStore
    @State private var activeField: String?
    @State private var imageSource: UIImagePickerController.SourceType?
    @State private var showDialog = false
    @State private var showFileImporter = false

    private var rows: [(field: String, label: String, required: Bool)] {
        RegisterStore.requiredDocs.map { ($0.field, $0.label, true) }
            + [("additional_documents", "Additional Documents", false)]
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Upload clear photos or PDFs (max 5MB each).")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(rows, id: \.field) { row in
                HStack(spacing: 12) {
                    Image(systemName: store.documents[row.field] != nil ? "checkmark.circle.fill" : "doc")
                        .foregroundColor(store.documents[row.field] != nil ? Brand.success : Brand.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label + (row.required ? " *" : ""))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        if let doc = store.documents[row.field] {
                            Text(doc.fileName).font(.system(size: 11)).foregroundColor(Brand.textSecondary).lineLimit(1)
                        } else {
                            Text("Not uploaded").font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                        }
                    }
                    Spacer()
                    Button(store.documents[row.field] != nil ? "Replace" : "Upload") {
                        activeField = row.field
                        showDialog = true
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                }
                .padding(12).card(padding: 12)
            }
        }
        .confirmationDialog("Add document", isPresented: $showDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { imageSource = .camera }
            }
            Button("Photo Library") { imageSource = .photoLibrary }
            Button("Choose PDF") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(get: { imageSource.map { SourceWrap(type: $0) } },
                             set: { imageSource = $0?.type })) { wrap in
            ImagePicker(sourceType: wrap.type, allowsEditing: false) { img in
                if let field = activeField, let data = img.jpegData(compressionQuality: 0.85) {
                    store.documents[field] = RegDocument(fileName: "\(field).jpg",
                                                         mimeType: "image/jpeg", data: data)
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result, let field = activeField {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    store.documents[field] = RegDocument(fileName: url.lastPathComponent,
                                                         mimeType: "application/pdf", data: data)
                }
            }
        }
    }
}

// MARK: - Step 6: Distributors / delivery / payment

private struct DistributorsStep: View {
    @ObservedObject var store: RegisterStore
    @State private var showDistributors = false
    @State private var showPayment = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                DropdownField(title: "Preferred Distributors",
                              value: store.selectedDistributorIds.isEmpty ? "" :
                                "\(store.selectedDistributorIds.count) selected",
                              placeholder: "Select distributors") { showDistributors = true }
                if !store.selectedDistributorIds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.distributors.filter { store.selectedDistributorIds.contains($0.id) }) { d in
                                RemovableChip(label: d.displayName) { store.selectedDistributorIds.remove(d.id) }
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Delivery Days").font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RegisterStore.allDays, id: \.self) { day in
                            SelectChip(label: day, selected: store.deliveryDays.contains(day)) {
                                if store.deliveryDays.contains(day) { store.deliveryDays.remove(day) }
                                else { store.deliveryDays.insert(day) }
                            }
                        }
                    }
                }
            }

            DropdownField(title: "Payment Method", value: store.paymentLabel,
                          placeholder: "Select payment method") { showPayment = true }
        }
        .confirmationDialog("Payment Method", isPresented: $showPayment, titleVisibility: .visible) {
            ForEach(RegisterStore.paymentOptions, id: \.code) { opt in
                Button(opt.label) { store.paymentMethod = opt.code }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDistributors) {
            MultiSelectSheet(title: "Preferred Distributors",
                             options: store.distributors.map { ($0.id, $0.displayName) },
                             selected: $store.selectedDistributorIds)
        }
    }
}

// MARK: - Step 7: Wallet

private struct WalletStep: View {
    @ObservedObject var store: RegisterStore
    var body: some View {
        VStack(spacing: 14) {
            walletOption(title: "Create anokiX Wallet now",
                         subtitle: "Pay distributors instantly and unlock cashback rewards.",
                         selected: store.createWallet) { store.createWallet = true }
            walletOption(title: "Activate later",
                         subtitle: "You can set up your wallet after approval.",
                         selected: !store.createWallet) { store.createWallet = false }
        }
    }

    private func walletOption(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? Brand.purple : Brand.textTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(14)
            .background(selected ? Brand.purpleLight : Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Brand.purple : Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 8: Terms

private struct TermsStep: View {
    @ObservedObject var store: RegisterStore
    var body: some View {
        VStack(spacing: 12) {
            term("I confirm all information provided is accurate.", $store.termAccurate)
            term("I accept the Terms of Service and Trader Agreement.", $store.termTos)
            term("I consent to KYC and document verification.", $store.termKyc)
            term("I agree to receive order and account communications.", $store.termComms)
        }
    }

    private func term(_ text: String, _ binding: Binding<Bool>) -> some View {
        Button { binding.wrappedValue.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: binding.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(binding.wrappedValue ? Brand.purple : Brand.textTertiary)
                Text(text).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12).card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Multi-select sheet

struct MultiSelectSheet: View {
    let title: String
    let options: [(Int, String)]
    @Binding var selected: Set<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.0) { id, label in
                    Button {
                        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                    } label: {
                        HStack {
                            Text(label).foregroundColor(Brand.textPrimary)
                            Spacer()
                            if selected.contains(id) {
                                Image(systemName: "checkmark").foregroundColor(Brand.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Completed screen

struct RegisterCompletedView: View {
    let onBackToLogin: () -> Void

    private let steps = [
        ("doc.text", "We review your documents"),
        ("checkmark.shield", "KYC verification"),
        ("person.2", "Distributor approval"),
        ("wallet.pass", "Wallet activation")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundColor(Brand.success)
            Text("Application Submitted!").font(.system(size: 24, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Text("Your trader account is under review. This usually takes 24–48 hours.")
                .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                Text("What happens next?").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0).foregroundColor(Brand.purple).frame(width: 24)
                        Text(item.1).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                        Spacer()
                    }
                }
            }
            .padding(16).card()
            .padding(.horizontal, 24)

            Spacer()
            Button("Back to Login", action: onBackToLogin)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(Brand.background.ignoresSafeArea())
    }
}
