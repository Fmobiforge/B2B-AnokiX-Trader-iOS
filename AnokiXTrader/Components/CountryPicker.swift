import SwiftUI

/// Searchable list of all dialling countries — the SwiftUI counterpart of the
/// Distributor app's `CountryPickerViewController`. Presented as a sheet from the
/// phone fields so the user can pick any country's dial code.
struct CountryPickerSheet: View {
    @Binding var selection: Country
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Country] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Countries.all }
        return Countries.all.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.dialCode.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selection = country
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag).font(.system(size: 22))
                        Text(country.name)
                            .font(.system(size: 15))
                            .foregroundColor(Brand.textPrimary)
                        Spacer()
                        Text(country.dialCode)
                            .font(.system(size: 14))
                            .foregroundColor(Brand.textSecondary)
                        if country == selection {
                            Image(systemName: "checkmark").foregroundColor(Brand.purple)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select country")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search country")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)   // always render clear/light, even in Dark Mode
    }
}
