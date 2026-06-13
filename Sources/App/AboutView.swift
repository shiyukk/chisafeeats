import SwiftUI

/// About / data-source attribution and disclaimers.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let datasetURL = URL(string: "https://data.cityofchicago.org/Health-Human-Services/Food-Inspections/4ijn-s7e5")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        Image("BrandIcon")
                            .resizable()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized("app.name")).font(.headline)
                            Text(localized("app.tagline")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .glassCard()

                    GlassGroup(title: localized("about.source")) {
                        VStack(alignment: .leading, spacing: 0) {
                            row(localized("about.dataset"), localized("about.datasetValue"))
                            Divider()
                            row(localized("about.publisher"), localized("about.publisherValue"))
                            Divider()
                            row(localized("about.platform"), localized("about.platformValue"))
                            Divider()
                            row(localized("about.datasetID"), "4ijn-s7e5")
                            Divider()
                            Button { openURL(datasetURL) } label: {
                                Label(localized("about.viewDataset"), systemImage: "safari")
                                    .font(.subheadline)
                                    .padding(.vertical, 11)
                            }
                        }
                    }

                    GlassGroup(title: localized("about.disclaimer")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(localized("about.unofficial")).font(.subheadline.weight(.medium))
                            Text(localized("about.notesRaw")).font(.subheadline).foregroundStyle(.secondary)
                            Text(localized("about.disclaimerScore")).font(.subheadline).foregroundStyle(.secondary)
                            Text(localized("about.disclaimerMT")).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(localized("legend.about"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(localized("common.done")) { dismiss() } }
            }
        }
        // Let the map show through so the cards read as real (translucent) glass
        // rather than flat light/white panels.
        .presentationBackground(.ultraThinMaterial)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 11)
    }
}
