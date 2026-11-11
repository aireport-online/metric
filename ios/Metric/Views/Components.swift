import SwiftUI
import MapKit
import MetricCore

/// Rond sporticoon.
struct ActivityIcon: View {
    let type: ActivityType
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: type.symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Eén kerngetal met een label eronder.
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// De kerngetallen van een activiteit als raster.
struct ActivityStatsGrid: View {
    let type: ActivityType
    let durationSeconds: Double
    let distanceMeters: Double?
    let elevationGainMeters: Double?
    let activeEnergyKcal: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?

    private struct Item: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    private var items: [Item] {
        var items = [Item(title: "Tijd", value: Format.duration(durationSeconds))]
        if let distanceMeters, distanceMeters > 0 {
            items.append(Item(title: "Afstand", value: Format.distance(distanceMeters)))
            if let pace = Format.paceOrSpeed(type: type, distanceMeters: distanceMeters, durationSeconds: durationSeconds) {
                items.append(Item(title: type.prefersSpeed ? "Snelheid" : "Tempo", value: pace))
            }
        }
        if let elevationGainMeters, elevationGainMeters > 0 {
            items.append(Item(title: "Stijging", value: "\(Int(elevationGainMeters.rounded())) m"))
        }
        if let activeEnergyKcal, activeEnergyKcal > 0 {
            items.append(Item(title: "Energie", value: "\(Int(activeEnergyKcal.rounded())) kcal"))
        }
        if let avgHeartRate, avgHeartRate > 0 {
            items.append(Item(title: "Gem. hartslag", value: "\(Int(avgHeartRate.rounded())) bpm"))
        }
        if let maxHeartRate, maxHeartRate > 0 {
            items.append(Item(title: "Max. hartslag", value: "\(Int(maxHeartRate.rounded())) bpm"))
        }
        return items
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                StatTile(title: item.title, value: item.value)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Kaart met de GPS-route van een activiteit.
struct RouteMapView: View {
    /// Lijst van `[lat, lon]`.
    let route: [[Double]]

    private var coordinates: [CLLocationCoordinate2D] {
        route.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
    }

    var body: some View {
        Map(initialPosition: .automatic) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.accentColor, lineWidth: 4)
        }
        .frame(height: 240)
        .accessibilityLabel("Kaart met de route")
    }
}

/// Korte samenvatting onder een titel: afstand en tijd.
func activitySummary(durationSeconds: Double, distanceMeters: Double?) -> String {
    if let distanceMeters, distanceMeters > 0 {
        return "\(Format.distance(distanceMeters)) · \(Format.durationShort(durationSeconds))"
    }
    return Format.durationShort(durationSeconds)
}

/// Rij voor een lokale activiteit.
struct ActivityRecordRow: View {
    let record: ActivityRecord

    var body: some View {
        HStack(spacing: 12) {
            ActivityIcon(type: record.type)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title.isEmpty ? record.type.displayName : record.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(activitySummary(durationSeconds: record.durationSeconds, distanceMeters: record.distanceMeters))
                    .font(.subheadline)
                    .monospacedDigit()
                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if record.syncState != .synced {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Nog niet gesynchroniseerd")
            }
        }
        .padding(.vertical, 2)
    }
}

/// Lege toestand met icoon, titel en uitleg.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}

extension Error {
    /// De Nederlandse melding van de API, of anders de systeemmelding.
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
