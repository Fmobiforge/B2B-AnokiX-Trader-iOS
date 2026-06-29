import SwiftUI

/// Invoices screen. Lists the trader's invoices (GET api/trader/invoices) with a
/// KPI summary (total count / total value / average / this month, all computed
/// client-side). Each invoice can be exported to PDF (GET .../{id}/pdf → base64)
/// and previewed in the shared in-app PDF viewer (`GrvPdfView`/`PDFDoc`).
struct InvoicesView: View {
    @StateObject private var store = InvoicesStore()
    @State private var pdfDoc: PDFDoc?
    @State private var toastMsg: String?

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statStrip
                content
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if store.invoices.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        .sheet(item: $pdfDoc) { doc in
            GrvPdfView(doc: doc)
        }
        .toast($toastMsg)
    }

    private var statStrip: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            StatTile(label: "Total Invoices", value: "\(store.totalCount)", icon: "doc.text.fill", iconTint: Brand.info)
            StatTile(label: "Total Value", value: Money.rand(store.totalValue), icon: "dollarsign.circle.fill", iconTint: Brand.success)
            StatTile(label: "Average Invoice", value: Money.rand(store.averageValue), icon: "chart.line.uptrend.xyaxis", iconTint: Brand.warning)
            StatTile(label: "This Month", value: "\(store.thisMonthCount)", valueColor: Brand.purple, icon: "calendar", iconTint: Brand.purple)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.invoices.isEmpty {
            ProgressView().padding(.top, 60)
        } else if store.invoices.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(store.invoices) { inv in
                    InvoiceCard(invoice: inv, onPdf: { openPdf(inv) })
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text("No invoices yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("An invoice appears here once one of your orders is delivered.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    // MARK: PDF

    private func openPdf(_ inv: InvoiceDTO) {
        toastMsg = "Generating PDF…"
        Task {
            do {
                let pdf = try await APIClient.shared.getInvoicePdf(id: inv.id)
                guard let b64 = pdf.data,
                      let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else {
                    toastMsg = "PDF unavailable."
                    return
                }
                let name = (pdf.filename?.isEmpty == false) ? pdf.filename! : "\(inv.invoice_number).pdf"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try bytes.write(to: url)
                toastMsg = nil
                pdfDoc = PDFDoc(url: url, title: inv.invoice_number)
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription ?? "Couldn't open PDF."
            }
        }
    }
}

// MARK: - Invoice card

private struct InvoiceCard: View {
    let invoice: InvoiceDTO
    let onPdf: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(invoice.invoice_number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Brand.purple)
                Spacer()
                StatusBadge(text: invoice.statusLabel, fg: invoice.statusTone.fg, bg: invoice.statusTone.bg)
            }
            Text("Order \(invoice.order_number ?? "—") · \(invoice.lineCount) item(s)")
                .font(.system(size: 13))
                .foregroundColor(Brand.textPrimary)
            Text(InvoiceFmt.date(invoice.created_at))
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)

            Divider().padding(.top, 6)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Amount")
                        .font(.system(size: 10))
                        .foregroundColor(Brand.textSecondary)
                    Text(Money.rand(invoice.total_amount))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Brand.textPrimary)
                }
                Spacer()
                Button(action: onPdf) {
                    Label("PDF", systemImage: "doc.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.textPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .card()
    }
}
