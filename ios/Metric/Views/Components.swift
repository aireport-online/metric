import SwiftUI
import MapKit
import MetricCore

/// Sporticoon in de tint van de sport, op een neutraal vlak.
struct ActivityIcon: View {
    let type: ActivityType
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: type.symbolName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(type.tint)
            .frame(width: size, height: size)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Dun streepje in de sporttint, naast de naam van de sport.
struct SportStripe: View {
    let type: ActivityType
    var height: CGFloat = 14

    var body: some View {
        Capsule()
            .fill(type.tint)
            .frame(width: 3, height: height)
            .accessibilityHidden(true)
    }
}

/// Eén kerngetal: groot cursief cijfer, de eenheid klein ernaast, het label eronder.
struct StatTile: View {
    let title: String
    let value: String
    var unit: String?
    var size: CGFloat = 28
    var tint: Color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FigureText(value: value, unit: unit, size: size, tint: tint)
            Text(title)
                .font(.metricLabel(14))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
        var unit: String?
        var id: String { title }
    }

    private var items: [Item] {
        var items = [Item(title: "Tijd", value: Format.duration(durationSeconds))]
        if let distanceMeters, distanceMeters > 0 {
            let distance = splitFigure(Format.distance(distanceMeters))
            items.append(Item(title: "Afstand", value: distance.value, unit: distance.unit))
            if let pace = Format.paceOrSpeed(type: type, distanceMeters: distanceMeters, durationSeconds: durationSeconds) {
                let parts = splitFigure(pace)
                items.append(Item(title: type.prefersSpeed ? "Snelheid" : "Tempo", value: parts.value, unit: parts.unit))
            }
        }
        if let elevationGainMeters, elevationGainMeters > 0 {
            items.append(Item(title: "Stijging", value: "\(Int(elevationGainMeters.rounded()))", unit: "m"))
        }
        if let activeEnergyKcal, activeEnergyKcal > 0 {
            items.append(Item(title: "Energie", value: "\(Int(activeEnergyKcal.rounded()))", unit: "kcal"))
        }
        if let avgHeartRate, avgHeartRate > 0 {
            items.append(Item(title: "Gem. hartslag", value: "\(Int(avgHeartRate.rounded()))", unit: "bpm"))
        }
        if let maxHeartRate, maxHeartRate > 0 {
            items.append(Item(title: "Max. hartslag", value: "\(Int(maxHeartRate.rounded()))", unit: "bpm"))
        }
        return items
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                StatTile(title: item.title, value: item.value, unit: item.unit, size: 26)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Het belangrijkste cijfer van een activiteit: de afstand, of anders de tijd. Telt op bij binnenkomst.
struct ActivityHeroFigure: View {
    let type: ActivityType
    let durationSeconds: Double
    let distanceMeters: Double?
    var size: CGFloat = 72

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let distanceMeters, distanceMeters >= 1000 {
                CountUp(value: distanceMeters, format: { Format.kilometers($0) })
                    .font(.metricNumber(size))
                Text("km")
                    .font(.metricLabel(size * 0.32))
                    .foregroundStyle(Theme.textMuted)
            } else if let distanceMeters, distanceMeters > 0 {
                CountUp(value: distanceMeters)
                    .font(.metricNumber(size))
                Text("m")
                    .font(.metricLabel(size * 0.32))
                    .foregroundStyle(Theme.textMuted)
            } else {
                CountUp(value: durationSeconds, format: { Format.duration($0) })
                    .font(.metricNumber(size))
            }
        }
        .foregroundStyle(Theme.text)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activitySummary(durationSeconds: durationSeconds, distanceMeters: distanceMeters))
    }
}

/// Kaart met de GPS-route van een activiteit, in tartan.
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
                .stroke(Theme.tartan, lineWidth: 4)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
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

/// Het cijfer rechts in een regel: de afstand als die er is, anders de tijd.
struct ActivityRowFigure: View {
    let durationSeconds: Double
    let distanceMeters: Double?

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let distanceMeters, distanceMeters > 0 {
                let distance = splitFigure(Format.distance(distanceMeters))
                FigureText(value: distance.value, unit: distance.unit, size: 26)
                Text(Format.duration(durationSeconds))
                    .font(.metricLabel(14))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textMuted)
            } else {
                FigureText(value: Format.duration(durationSeconds), size: 26)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activitySummary(durationSeconds: durationSeconds, distanceMeters: distanceMeters))
    }
}

/// Rij voor een lokale activiteit.
struct ActivityRecordRow: View {
    let record: ActivityRecord

    var body: some View {
        HStack(spacing: 12) {
            ActivityIcon(type: record.type)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title.isEmpty ? record.type.displayName : record.title)
                    .font(.metricText(16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    SportStripe(type: record.type, height: 11)
                    Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                    if record.syncState != .synced {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(Theme.textMuted)
                            .accessibilityLabel("Nog niet gesynchroniseerd")
                    }
                }
            }
            Spacer(minLength: 8)
            ActivityRowFigure(durationSeconds: record.durationSeconds, distanceMeters: record.distanceMeters)
        }
    }
}

/// Lege toestand: een lege baan, wat er ontbreekt en de eerste stap.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            TrackProgressView(lanes: [TrackLane(progress: 0)], laneWidth: 8, aspect: 2) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(width: 150)
            .accessibilityHidden(true)
            Text(title)
                .font(.metricHeading(24))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.metricText(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// Kop boven een sectie, in zinsvorm.
struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.metricHeading(20))
            .foregroundStyle(Theme.text)
            .textCase(nil)
    }
}

/// Initiaal van een gebruiker op een neutraal vlak.
struct UserAvatar: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.metricHeading(size * 0.5))
            .foregroundStyle(Theme.text)
            .frame(width: size, height: size)
            .background(Theme.surfaceRaised, in: Circle())
            .overlay(Circle().stroke(Theme.lineStrong, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Achtergrond van een `List` of `Form` in de huisstijl.
    func metricListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
    }

    /// Rij van een gegroepeerde lijst op het Baanvlak.
    func metricRow() -> some View {
        self
            .listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.line)
    }

    /// Lijstregel als losse kaart (voor `List` met `.plain`-stijl).
    func cardRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 18, leading: 32, bottom: 18, trailing: 28))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.surface)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 16)
            )
    }

    /// Invoerveld op het verhoogde vlak met straal 14.
    func metricField() -> some View {
        self
            .font(.metricText(16))
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.lineStrong, lineWidth: 1)
            )
    }
}

extension Error {
    /// De Nederlandse melding van de API, of anders de systeemmelding.
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
