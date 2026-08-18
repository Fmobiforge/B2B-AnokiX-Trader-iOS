import SwiftUI
import CoreLocation

/// Make Order / Checkout (mirrors Design/MakeOrder). Confirms the delivery
/// address, delivery window, notes and payment method for the cart lines
/// selected on the Cart screen, then places the order via
/// `api/trader/orders/create`. Delivery slots are generated locally from the
/// trader's `portal_info.preferred_delivery_days`; the default address comes
/// from `portal_info.address`. Mirrors the Android `MakeOrderActivity`.
struct MakeOrderView: View {
    @ObservedObject var store: MarketStore
    /// Called after a successful order so the caller can dismiss back to the marketplace.
    let onOrderPlaced: () -> Void

    @State private var address: String
    @State private var slots: [DeliverySlot]
    @State private var selectedSlotId: UUID?
    @State private var notes = ""
    @State private var paymentKey = "wallet"
    @State private var placing = false
    @State private var toastMsg: String?
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Int, Identifiable {
        case address, allSlots
        var id: Int { rawValue }
    }

    private let payments: [(key: String, title: String, subtitle: String)] = [
        ("wallet", "Wallet Balance", "anokiX wallet"),
        //("credit", "Credit Account", "Pay on terms"),
        ("card", "Card Payment", "Visa, Mastercard"),
        ("bank", "Bank Transfer", "EFT / Instant EFT")
    ]

    init(store: MarketStore, onOrderPlaced: @escaping () -> Void) {
        self.store = store
        self.onOrderPlaced = onOrderPlaced
        let info = LoginSessionStore.load()?.portal_info
        _address = State(initialValue: info?.address ?? "")
        // Delivery slots come from the SELECTED DISTRIBUTOR's preferred_delivery_days
        // (marketplace response); fall back to the trader's own login value if absent.
        let distDays = store.data?.selected_distributor?.preferred_delivery_days
        let deliveryDays = (distDays?.isEmpty == false) ? distDays : info?.preferred_delivery_days
        let generated = DeliverySlot.generate(from: deliveryDays)
        _slots = State(initialValue: generated)
        _selectedSlotId = State(initialValue: generated.first?.id)
    }

    private var currency: String { store.currency }
    private var subtotal: Double { store.selectedSubtotal }
    private var selectedSlot: DeliverySlot? { slots.first { $0.id == selectedSlotId } }

    /// Selected slot first, then the earliest others, capped at 5 (matches design).
    private var inlineSlots: [DeliverySlot] {
        var result: [DeliverySlot] = []
        if let sel = selectedSlot { result.append(sel) }
        for s in slots where result.count < 5 && s.id != selectedSlotId {
            result.append(s)
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                addressCard
                deliveryWindowCard
                notesCard
                paymentCard
                summaryCard
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Make Order")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .address:
                AddressSearchSheet(address: $address)
            case .allSlots:
                AllSlotsSheet(slots: slots, selectedId: $selectedSlotId)
            }
        }
        .toast($toastMsg)
    }

    // MARK: - Cards

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Delivery Address").font(.system(size: 16, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Button("Change") { activeSheet = .address }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.purple)
            }
            Text(address.isEmpty ? "No delivery address set." : address)
                .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
        }
        .card()
    }

    private var deliveryWindowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Delivery Window").font(.system(size: 16, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            if slots.isEmpty {
                Text("No delivery slots available.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            } else {
                ForEach(inlineSlots) { slot in
                    OrderOptionRow(title: slot.label, selected: slot.id == selectedSlotId) {
                        selectedSlotId = slot.id
                    }
                }
                if slots.count > 5 {
                    Button("View all slots") { activeSheet = .allSlots }
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.purple)
                        .padding(.top, 2)
                }
            }
        }
        .card()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Special Instructions (Optional)").font(.system(size: 16, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            TextField("E.g. Gate code, store hours, etc.", text: $notes, axis: .vertical)
                .font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                .lineLimit(3...6)
                .padding(12)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
        }
        .card()
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Payment Method").font(.system(size: 16, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            ForEach(payments, id: \.key) { p in
                OrderOptionRow(title: p.title, subtitle: p.subtitle, selected: p.key == paymentKey) {
                    paymentKey = p.key
                }
            }
        }
        .card()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary").font(.system(size: 18, weight: .bold)).foregroundColor(Brand.textPrimary)
            HStack {
                Text("Subtotal").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text(CurrencyFmt.format(subtotal, symbol: currency))
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
            }
            HStack {
                Text("Delivery Fee").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text("FREE").font(.system(size: 14, weight: .bold)).foregroundColor(Brand.success)
            }
            Divider()
            HStack {
                Text("Total").font(.system(size: 18, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Text(CurrencyFmt.format(subtotal, symbol: currency))
                    .font(.system(size: 20, weight: .bold)).foregroundColor(Brand.purple)
            }
            Text("Incl. VAT").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            Button(placing ? "Placing order…" : "Order \(CurrencyFmt.format(subtotal, symbol: currency))") {
                placeOrder()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(placing)
            .padding(.top, 4)
        }
        .card()
    }

    // MARK: - Place order

    private func placeOrder() {
        guard !store.selectedLines.isEmpty else {
            toastMsg = "Select at least one item to order."; return
        }
        guard let slot = selectedSlot else {
            toastMsg = "Please choose a delivery window."; return
        }
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else {
            toastMsg = "No delivery address set."; return
        }
        let ids = store.selectedLines.compactMap { $0.cartItemId }
        guard !ids.isEmpty else {
            toastMsg = "Select at least one item to order."; return
        }
        let distId = store.selectedLines.compactMap { $0.distributorId }.first

        placing = true
        Task {
            do {
                try await APIClient.shared.createOrder(
                    distributorId: distId, cartItemIds: ids,
                    deliveryDate: slot.deliveryDate, startTime: slot.startApi, endTime: slot.endApi,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    deliveryAddress: address, paymentMethod: paymentKey)
                await store.refreshCart()
                await MainActor.run { toastMsg = "Order placed successfully." }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run { onOrderPlaced() }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to place order."
                await MainActor.run { placing = false; toastMsg = msg }
            }
        }
    }
}

// MARK: - Reusable selectable row

private struct OrderOptionRow: View {
    let title: String
    var subtitle: String? = nil
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? Brand.purple : Brand.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Brand.purpleLight : Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Brand.purple : Brand.border, lineWidth: selected ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Address search sheet

private struct AddressSearchSheet: View {
    @Binding var address: String
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var localAddress: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var focus: CLLocationCoordinate2D?
    @State private var suggestions: [AddressSuggestion] = []
    @State private var searching = false

    init(address: Binding<String>) {
        _address = address
        _query = State(initialValue: address.wrappedValue)
        _localAddress = State(initialValue: address.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search delivery address").font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                HStack {
                    TextField("Search delivery address", text: $query)
                        .font(.system(size: 15)).foregroundColor(Brand.textPrimary)
                        .onChange(of: query) { _ in search() }
                    if searching { ProgressView() }
                }
                .padding(14).background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if !suggestions.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(suggestions) { s in
                                Button { resolve(s) } label: {
                                    HStack {
                                        Image(systemName: "mappin.circle").foregroundColor(Brand.purple)
                                        Text(s.description).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10).padding(.horizontal, 4)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                }

                GoogleMapView(latitude: $latitude, longitude: $longitude,
                              address: $localAddress, focus: $focus)
                    .frame(maxWidth: .infinity).frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("Tap the map to drop a pin, or drag the pin to set the location.")
                    .font(.system(size: 11)).foregroundColor(Brand.textSecondary)

                Button("Use this address") {
                    let chosen = localAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                    address = chosen.isEmpty ? query : chosen
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Spacer()
            }
            .padding(16)
            .background(Brand.background)
            .navigationTitle("Delivery Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
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
        localAddress = s.description
        query = s.description
        suggestions = []
        Task {
            if let coord = try? await APIClient.shared.coordinate(placeId: s.place_id) {
                await MainActor.run {
                    latitude = coord.lat
                    longitude = coord.lng
                    if let a = coord.resolvedAddress, !a.isEmpty { localAddress = a; query = a }
                    if let lat = coord.lat, let lng = coord.lng {
                        focus = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                }
            }
        }
    }
}

// MARK: - All slots sheet

private struct AllSlotsSheet: View {
    let slots: [DeliverySlot]
    @Binding var selectedId: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(slots) { slot in
                        OrderOptionRow(title: slot.label, selected: slot.id == selectedId) {
                            selectedId = slot.id
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
            .navigationTitle("All Delivery Slots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
