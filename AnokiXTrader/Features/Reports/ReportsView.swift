import SwiftUI

struct ReportsView: View {
    @State private var category = "All"
    @State private var toastMsg: String?
    private let statCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let reportTypes: [(String, String)] = [
        ("📊", "Sales Report"), ("🧾", "POS Summary"), ("📦", "Inventory"),
        ("🛒", "Marketplace"), ("💰", "Wallet"), ("🎁", "Rewards"),
    ]

    private var reports: [TraderReport] {
        category == "All" ? MockData.reports : MockData.reports.filter { $0.categoryLabel == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: statCols, spacing: 12) {
                    StatTile(label: "Generated", value: "186", icon: "doc.text", iconTint: Brand.purple)
                    StatTile(label: "Downloads", value: "142", icon: "arrow.down.circle", iconTint: Brand.info)
                    StatTile(label: "Scheduled", value: "8", icon: "calendar", iconTint: Brand.warning)
                    StatTile(label: "Shared", value: "22", icon: "square.and.arrow.up", iconTint: Brand.success)
                }

                Text("Generate Report").font(.system(size: 17, weight: .bold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(reportTypes, id: \.1) { t in
                        Button { toastMsg = "Generating \(t.1)…" } label: {
                            VStack(spacing: 6) {
                                Text(t.0).font(.system(size: 26))
                                Text(t.1).font(.system(size: 11, weight: .medium)).foregroundColor(Brand.textPrimary)
                                    .multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 14).card(padding: 6)
                        }.buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MockData.reportCategories, id: \.self) { c in
                            FilterChip(label: c, selected: c == category) { category = c }
                        }
                    }
                }

                ListCard(title: "Recent Reports") {
                    VStack(spacing: 0) {
                        ForEach(Array(reports.enumerated()), id: \.element.id) { idx, r in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill").foregroundColor(Color(hex: r.colorHex))
                                    .frame(width: 40, height: 40).background(Color(hex: r.colorHex).opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                    Text("\(r.period) · \(r.format) · \(r.fileSize)").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                                }
                                Spacer()
                                StatusBadge(text: r.status.replacingOccurrences(of: "_", with: " ").capitalized,
                                            fg: badgeTone(r.status).fg, bg: badgeTone(r.status).bg)
                            }
                            .padding(.vertical, 10)
                            if idx < reports.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .toast($toastMsg)
    }
}
