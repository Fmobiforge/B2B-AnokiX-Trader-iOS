import SwiftUI

/// Distributors screen. Lists the distributors the trader is partnered with
/// (GET api/trader/distributors). "View Distributor" pushes a detail screen where
/// a change of distributor can be requested
/// (POST api/trader/distributor/change-request).
struct DistributorsView: View {
    @StateObject private var store = DistributorsStore()
    @State private var toastMsg: String?

    var body: some View {
        ScrollView {
            content.padding(16)
        }
        .background(Brand.background)
        .task { if store.distributors.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        .toast($toastMsg)
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.distributors.isEmpty {
            ProgressView().padding(.top, 60)
        } else if store.distributors.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(store.distributors) { d in
                    NavigationLink {
                        DistributorDetailView(distributor: d, store: store, toast: { toastMsg = $0 })
                    } label: {
                        DistributorCard(distributor: d)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text("No distributors yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("Your assigned distributors will appear here.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }
}

// MARK: - List card

private struct DistributorCard: View {
    let distributor: TraderDistributorDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                DistributorAvatar(logoUrl: distributor.logo_url, initial: distributor.initial, size: 48)
                Text(distributor.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.purple)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack {
                Text("Products Available")
                    .font(.system(size: 13))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                Text("\(distributor.products_available)+")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
            }

            HStack(alignment: .top, spacing: 12) {
                Label("Coverage Area", systemImage: "mappin.and.ellipse")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 13))
                    .foregroundColor(Brand.textSecondary)
                    .fixedSize()
                Spacer(minLength: 8)
                Text(distributor.address ?? "—")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .multilineTextAlignment(.trailing)
            }

            Text("View Distributor")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Brand.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
        }
        .card()
    }
}

// MARK: - Detail

private struct DistributorDetailView: View {
    let distributor: TraderDistributorDTO
    @ObservedObject var store: DistributorsStore
    let toast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showChangeForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                infoGrid
                contactCard
                performance
                Button { showChangeForm = true } label: {
                    Text("Request Change Distributor")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Brand.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Distributor Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChangeForm) {
            ChangeDistributorForm(distributor: distributor, store: store) { message in
                showChangeForm = false
                if let message { toast(message) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            DistributorAvatar(logoUrl: distributor.logo_url, initial: distributor.initial, size: 56)
            VStack(alignment: .leading, spacing: 8) {
                Text(distributor.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Brand.purple)
                if distributor.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11))
                        Text("Your Preferred Distributor").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Brand.success)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Brand.successBg)
                    .clipShape(Capsule())
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var infoGrid: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                infoCell("Coverage Area", distributor.address ?? "—")
                infoCell("Products Available", "\(distributor.products_available)+")
            }
            Divider()
            HStack(alignment: .top, spacing: 12) {
                infoCell("Delivery SLA", "—")
                infoCell("Minimum Order", distributor.minimum_order ?? "—")
            }
        }
        .card()
    }

    private func infoCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            contactRow("person", distributor.contact_name ?? "—")
            contactRow("envelope", distributor.contact_email ?? "—")
            contactRow("phone", distributor.contact_phone ?? "—")
        }
        .card()
    }

    private func contactRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(Brand.purple).frame(width: 20)
            Text(text).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
            Spacer(minLength: 0)
        }
    }

    /// Performance figures are not supplied by the API; these mirror the indicative
    /// values shown in the web portal design and are rendered statically.
    private var performance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Distributor Performance")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Brand.topTitle)
            HStack(alignment: .top, spacing: 12) {
                perfCell("On-time Delivery", "95%")
                perfCell("Order Accuracy", "98%")
            }
            HStack(alignment: .top, spacing: 12) {
                perfCell("Fill Rate", "96%")
                ratingCell("Customer Rating", "4.8")
            }
        }
        .padding(.top, 4)
    }

    private func perfCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.topTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ratingCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            HStack(spacing: 4) {
                Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.topTitle)
                Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(Color(hex: "#F59E0B"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Change request form

private struct ChangeDistributorForm: View {
    let distributor: TraderDistributorDTO
    @ObservedObject var store: DistributorsStore
    /// Called with an optional toast message; passing it dismisses the sheet.
    let onDone: (String?) -> Void

    @State private var reason = ""
    @State private var submitting = false
    @State private var errorMsg: String?

    private let maxLen = 1000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Submit a request to change your distributor from \(distributor.displayName). Our team will review it and get back to you.")
                        .font(.system(size: 13))
                        .foregroundColor(Brand.textSecondary)

                    VStack(alignment: .trailing, spacing: 4) {
                        TextField("Reason for change (optional)", text: $reason, axis: .vertical)
                            .lineLimit(5...10)
                            .font(.system(size: 14))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .background(Brand.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                            .onChange(of: reason) { newValue in
                                if newValue.count > maxLen { reason = String(newValue.prefix(maxLen)) }
                            }
                        Text("\(reason.count) / \(maxLen)")
                            .font(.system(size: 11))
                            .foregroundColor(Brand.textTertiary)
                    }

                    if let errorMsg {
                        Text(errorMsg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Brand.danger)
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
            .navigationTitle("Request Change Distributor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDone(nil) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { submit() } label: {
                        if submitting { ProgressView() } else { Text("Submit").fontWeight(.semibold) }
                    }
                    .disabled(submitting)
                }
            }
        }
    }

    private func submit() {
        submitting = true
        errorMsg = nil
        Task {
            do {
                try await store.requestChange(
                    currentDistributorId: distributor.id,
                    reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
                submitting = false
                onDone("Change request submitted. Our team will review it.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription ?? "Failed to submit distributor change request."
            }
        }
    }
}
