import Foundation
import SwiftData
import MetricCore

/// Synchronisatiestatus van een lokaal opgeslagen activiteit.
enum SyncState: String {
    /// Nieuw op dit toestel, nog niet geüpload.
    case pendingUpload
    /// Staat op de server, maar titel/notitie/zichtbaarheid/type is lokaal gewijzigd.
    case pendingUpdate
    /// Lokaal verwijderd; moet nog van de server af.
    case pendingDelete
    case synced
}

/// Een activiteit in de lokale SwiftData-opslag (offline-first).
@Model
final class ActivityRecord {
    @Attribute(.unique) var clientId: String
    var serverId: String?
    var healthKitUUID: String?
    var typeRaw: String
    var title: String
    var notes: String
    var startedAt: Date
    var durationSeconds: Double
    var distanceMeters: Double?
    var elevationGainMeters: Double?
    var activeEnergyKcal: Double?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var sourceRaw: String
    var visibilityRaw: String?
    /// JSON van `[[lat, lon]]`, al uitgedund tot maximaal 1000 punten.
    var routeData: Data?
    var hasRoute: Bool
    var syncStateRaw: String
    var kudosCount: Int
    var commentCount: Int
    var updatedAt: Date

    init(
        clientId: String,
        type: ActivityType,
        title: String,
        notes: String = "",
        startedAt: Date,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        elevationGainMeters: Double? = nil,
        activeEnergyKcal: Double? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        source: ActivitySource,
        visibility: ActivityVisibility? = nil,
        route: [[Double]]? = nil,
        healthKitUUID: String? = nil,
        syncState: SyncState = .pendingUpload
    ) {
        self.clientId = ClientID.normalize(clientId)
        self.serverId = nil
        self.healthKitUUID = healthKitUUID
        self.typeRaw = type.rawValue
        self.title = title
        self.notes = notes
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.activeEnergyKcal = activeEnergyKcal
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.sourceRaw = source.rawValue
        self.visibilityRaw = visibility?.rawValue
        if let route, route.count >= 2 {
            self.routeData = try? JSONEncoder().encode(route)
            self.hasRoute = true
        } else {
            self.routeData = nil
            self.hasRoute = false
        }
        self.syncStateRaw = syncState.rawValue
        self.kudosCount = 0
        self.commentCount = 0
        self.updatedAt = Date()
    }
}

extension ActivityRecord {
    var type: ActivityType {
        get { ActivityType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var source: ActivitySource {
        ActivitySource(rawValue: sourceRaw) ?? .web
    }

    var visibility: ActivityVisibility? {
        get { visibilityRaw.flatMap { ActivityVisibility(rawValue: $0) } }
        set { visibilityRaw = newValue?.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .synced }
        set { syncStateRaw = newValue.rawValue }
    }

    var isPendingDelete: Bool {
        syncState == .pendingDelete
    }

    /// De route als `[[lat, lon]]`, of leeg als die (nog) niet lokaal staat.
    var route: [[Double]] {
        guard let routeData else { return [] }
        return (try? JSONDecoder().decode([[Double]].self, from: routeData)) ?? []
    }

    func setRoute(_ route: [[Double]]) {
        guard route.count >= 2 else { return }
        routeData = try? JSONEncoder().encode(route)
        hasRoute = true
    }

    var sample: ActivitySample {
        ActivitySample(startedAt: startedAt, durationSeconds: durationSeconds, distanceMeters: distanceMeters)
    }

    /// De upload-body voor `POST /activities/batch`.
    func makeInput() -> ActivityInput {
        let route = self.route
        return ActivityInput(
            clientId: clientId,
            type: type,
            title: title.isEmpty ? nil : title,
            notes: notes.isEmpty ? nil : notes,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            activeEnergyKcal: activeEnergyKcal,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            source: source,
            visibility: visibility,
            route: route.count >= 2 ? RouteSimplifier.downsample(route) : nil
        )
    }

    /// Neemt de servertoestand over (na upload of bij het ophalen).
    func apply(_ activity: Activity) {
        serverId = activity.id
        typeRaw = activity.type.rawValue
        title = activity.title
        notes = activity.notes
        visibilityRaw = activity.visibility.rawValue
        kudosCount = activity.kudosCount
        commentCount = activity.commentCount
        if activity.hasRoute {
            hasRoute = true
        }
        if let route = activity.route, route.count >= 2, routeData == nil {
            routeData = try? JSONEncoder().encode(route)
        }
    }

    /// Maakt een lokaal record van een activiteit die alleen op de server stond.
    convenience init(remote activity: Activity) {
        self.init(
            clientId: activity.clientId,
            type: activity.type,
            title: activity.title,
            notes: activity.notes,
            startedAt: activity.startedAt,
            durationSeconds: activity.durationSeconds,
            distanceMeters: activity.distanceMeters,
            elevationGainMeters: activity.elevationGainMeters,
            activeEnergyKcal: activity.activeEnergyKcal,
            avgHeartRate: activity.avgHeartRate,
            maxHeartRate: activity.maxHeartRate,
            source: activity.source,
            visibility: activity.visibility,
            route: activity.route,
            syncState: .synced
        )
        serverId = activity.id
        hasRoute = activity.hasRoute
        kudosCount = activity.kudosCount
        commentCount = activity.commentCount
    }
}
