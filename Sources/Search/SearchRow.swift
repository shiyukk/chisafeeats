import SwiftUI

/// One search/nearby result row.
struct SearchRow: View {
    let establishment: EstablishmentRecord
    let distance: Double?

    private var result: InspectionResult {
        InspectionResult(rawValue: establishment.latestResultCode ?? InspectionResult.other.rawValue) ?? .other
    }

    /// Address · distance. The category is conveyed by the leading icon, not text.
    private var subtitle: String {
        var parts: [String] = []
        if let address = establishment.address, !address.isEmpty {
            parts.append(address.trimmingCharacters(in: .whitespaces))
        }
        if let distance { parts.append(Self.formatDistance(distance)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: FacilityIcon.symbol(for: establishment.facilityType))
                .font(.system(size: 15))
                .foregroundStyle(result.color)
                .frame(width: 38, height: 38)
                .background(result.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(establishment.dbaName).font(.body.weight(.medium)).lineLimit(1)
                Text(subtitle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if result.isScored, let score = establishment.score {
                    Text("\(score)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(result.color)
                    Text(result.label)
                        .font(.caption2).foregroundStyle(.secondary)
                } else if result == .outOfBusiness {
                    Text(InspectionResult.outOfBusiness.label)
                        .font(.caption.weight(.semibold)).foregroundStyle(.gray)
                } else {
                    // No Entry / Not Ready … — its own color and status, no score.
                    Text(result.displayLabel(raw: establishment.latestResult))
                        .font(.caption.weight(.semibold)).foregroundStyle(RatingStyle.noScore)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([
            establishment.dbaName,
            establishment.score.map { "\(localized("verdict.score")) \($0)" },
            result.displayLabel(raw: establishment.latestResult),
            distance.map(Self.formatDistance),
        ].compactMap { $0 }.joined(separator: ", "))
    }

    static func formatDistance(_ meters: Double) -> String {
        // Always in kilometers, locale-aware decimal separator ("0.8 公里" /
        // "1.2 km" / "1,2 km").
        let km = (meters / 1000).formatted(.number.precision(.fractionLength(1))
            .locale(Locale(identifier: currentAppLanguage().code)))
        return localized("dist.km", km)
    }
}
