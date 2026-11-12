import Foundation
import Combine
import CoreLocation
import HealthKit
import SwiftData
import MetricCore

/// Centrale app-toestand: sessie, API-client, sync, HealthKit-import en de koppeling met de Watch.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var me: Me?
    @Published private(set) var isRestoring = true
    @Published private(set) var serverURLString: String
    @Published private(set) var healthEnabled: Bool
    @Published private(set) var isImportingHealth = false

    let api: APIClient
    let sync: SyncService
    let health = HealthKitService()

    private let context: ModelContext
    private let defaults = UserDefaults.standard
    private let serverURLKey = "serverURL"
    private let cachedMeKey = "cachedMe"
    private var isRefreshing = false
    private var needsAnotherRefresh = false

    init(container: ModelContainer) {
        let context = container.mainContext
        self.context = context
        self.sync = SyncService(context: context)

        let stored = UserDefaults.standard.string(forKey: "serverURL")
        let urlString = AppModel.normalizeServerURL(stored ?? "") ?? AppModel.defaultServerURLString
        self.serverURLString = urlString
        self.api = APIClient(baseURL: URL(string: urlString) ?? URL(string: "http://localhost:3000")!)
        self.healthEnabled = UserDefaults.standard.bool(forKey: HealthKitService.enabledKey)

        PhoneConnectivity.shared.onWorkout = { [weak self] payload in
            Task { @MainActor in
                self?.handleWatchWorkout(payload)
            }
        }
        PhoneConnectivity.shared.activate()
    }

    // MARK: Server

    /// De standaard-server uit Info.plist (`MetricAPIBaseURL`, gevuld vanuit `Config/Metric.xcconfig`).
    static var defaultServerURLString: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "MetricAPIBaseURL") as? String
        return normalizeServerURL(value ?? "") ?? "http://localhost:3000"
    }

    static func normalizeServerURL(_ value: String) -> String? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme, url.host != nil else {
            return nil
        }
        guard scheme == "http" || scheme == "https" else { return nil }
        return trimmed
    }

    /// Stelt een andere server in. Geeft `false` terug als de URL ongeldig is.
    @discardableResult
    func setServerURL(_ value: String) -> Bool {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty {
            defaults.removeObject(forKey: serverURLKey)
            serverURLString = AppModel.defaultServerURLString
        } else {
            guard let normalized = AppModel.normalizeServerURL(candidate) else { return false }
            defaults.set(normalized, forKey: serverURLKey)
            serverURLString = normalized
        }
        if let url = URL(string: serverURLString) {
            api.baseURL = url
        }
        return true
    }

    /// Een link naar de website, bv. `/u/sam` of `/activities/<id>`.
    func webURL(_ path: String) -> URL? {
        URL(string: serverURLString + path)
    }

    // MARK: Sessie

    func restoreSession() async {
        guard isRestoring else { return }
        guard let token = KeychainStore.loadToken() else {
            isRestoring = false
            return
        }
        api.token = token
        if let cached = loadCachedMe() {
            // Direct verder met de laatst bekende gebruiker; hieronder verversen we.
            me = cached
            isRestoring = false
        }
        do {
            let user = try await api.me()
            setMe(user)
        } catch let error as APIError where error.isUnauthorized {
            endSession()
        } catch {
            // Offline: we werken door met de gecachte gebruiker.
        }
        isRestoring = false
    }

    func login(email: String, password: String) async throws {
        let response = try await api.login(email: email, password: password)
        startSession(response)
    }

    func register(email: String, password: String, username: String, displayName: String) async throws {
        let response = try await api.register(email: email, password: password, username: username, displayName: displayName)
        startSession(response)
    }

    func logout() async {
        // Probeer eerst nog te uploaden wat lokaal klaarstaat.
        await sync.sync(api: api)
        try? await api.logout()
        endSession()
    }

    func deleteAccount(password: String) async throws {
        try await api.deleteAccount(password: password)
        endSession()
    }

    func updateProfile(_ update: MeUpdate) async throws {
        let user = try await api.updateMe(update)
        setMe(user)
        pushWatchContext()
    }

    private func startSession(_ response: AuthResponse) {
        api.token = response.token
        KeychainStore.saveToken(response.token)
        setMe(response.user)
        Task {
            await refreshAll()
        }
    }

    private func endSession() {
        api.token = nil
        KeychainStore.deleteToken()
        defaults.removeObject(forKey: cachedMeKey)
        me = nil
        sync.deleteEverything()
        health.resetAnchor()
        pushWatchContext()
    }

    private func setMe(_ user: Me) {
        me = user
        if let data = try? MetricCoding.encoder().encode(user) {
            defaults.set(data, forKey: cachedMeKey)
        }
    }

    private func loadCachedMe() -> Me? {
        guard let data = defaults.data(forKey: cachedMeKey) else { return nil }
        return try? MetricCoding.decoder().decode(Me.self, from: data)
    }

    // MARK: Verversen

    /// Importeert nieuwe workouts uit Gezondheid, synchroniseert met de server en werkt de Watch bij.
    func refreshAll() async {
        guard me != nil else { return }
        if isRefreshing {
            needsAnotherRefresh = true
            return
        }
        isRefreshing = true
        repeat {
            needsAnotherRefresh = false
            await importHealthWorkouts()
            let error = await sync.sync(api: api)
            if let apiError = error as? APIError, apiError.isUnauthorized {
                endSession()
                break
            }
            if let user = try? await api.me(), me != nil {
                setMe(user)
            }
            pushWatchContext()
        } while needsAnotherRefresh && me != nil
        isRefreshing = false
    }

    func pushWatchContext() {
        let samples = sync.allRecords().filter { !$0.isPendingDelete }.map { $0.sample }
        let thisWeek = StatsCalculator.weekly(samples, weeks: 1).first
        let minutes = Int(((thisWeek?.durationSeconds ?? 0) / 60).rounded())
        let payload = WatchContextPayload(
            isLoggedIn: me != nil,
            displayName: me?.displayName,
            weekMinutes: me == nil ? 0 : minutes,
            goalMinutes: me?.weeklyGoalMinutes ?? 150,
            streakWeeks: me == nil ? 0 : StatsCalculator.streakWeeks(samples)
        )
        PhoneConnectivity.shared.send(context: payload)
    }

    // MARK: Gezondheid

    /// Vraagt toegang tot Gezondheid en importeert daarna de workouts.
    func enableHealth() async {
        // Demo-modus: geen toestemmingsvenster van Gezondheid tijdens de opname.
        guard health.isAvailable, !DemoMode.isActive else { return }
        do {
            try await health.requestAuthorization()
            health.isEnabled = true
            healthEnabled = true
            await refreshAll()
        } catch {
            // De gebruiker kan het later opnieuw proberen via Profiel.
        }
    }

    /// Haalt alle workouts van de afgelopen maanden opnieuw op (bv. na het wijzigen van de toegang).
    func reimportHealth() async {
        health.resetAnchor()
        await refreshAll()
    }

    private func importHealthWorkouts() async {
        guard me != nil, health.isAvailable, health.isEnabled, !isImportingHealth, !DemoMode.isActive else { return }
        isImportingHealth = true
        defer { isImportingHealth = false }

        guard let (workouts, commit) = try? await health.fetchNewWorkouts() else { return }

        var byClientId: [String: ActivityRecord] = [:]
        var knownHealthIds = Set<String>()
        for record in sync.allRecords() {
            byClientId[record.clientId] = record
            if let healthId = record.healthKitUUID {
                knownHealthIds.insert(healthId)
            }
        }

        for workout in workouts {
            let healthId = workout.uuid.uuidString.lowercased()
            if knownHealthIds.contains(healthId) || byClientId[healthId] != nil {
                continue
            }
            let imported = await health.makeImportedWorkout(from: workout)

            // Door Metric zelf opgenomen (iPhone of Watch): koppel aan het bestaande record.
            if let external = imported.externalClientId, let existing = byClientId[external] {
                existing.healthKitUUID = healthId
                knownHealthIds.insert(healthId)
                var changed = false
                if !existing.hasRoute, let route = imported.route {
                    existing.setRoute(route)
                    changed = true
                }
                if existing.distanceMeters == nil, let distance = imported.distanceMeters {
                    existing.distanceMeters = distance
                    changed = true
                }
                if existing.elevationGainMeters == nil, let elevation = imported.elevationGainMeters {
                    existing.elevationGainMeters = elevation
                    changed = true
                }
                if existing.avgHeartRate == nil, let heartRate = imported.avgHeartRate {
                    existing.avgHeartRate = heartRate
                    existing.maxHeartRate = imported.maxHeartRate
                    changed = true
                }
                if changed, existing.syncState == .synced {
                    // Opnieuw uploaden: de server werkt bij op basis van `clientId`.
                    existing.syncState = .pendingUpload
                }
                continue
            }

            // Hele korte workouts (per ongeluk gestart) slaan we over.
            guard imported.durationSeconds >= 60 else { continue }

            let hour = Calendar.current.component(.hour, from: imported.startedAt)
            let record = ActivityRecord(
                clientId: imported.externalClientId ?? healthId,
                type: imported.type,
                title: imported.type.defaultTitle(hour: hour),
                startedAt: imported.startedAt,
                durationSeconds: imported.durationSeconds,
                distanceMeters: imported.distanceMeters,
                elevationGainMeters: imported.elevationGainMeters,
                activeEnergyKcal: imported.activeEnergyKcal,
                avgHeartRate: imported.avgHeartRate,
                maxHeartRate: imported.maxHeartRate,
                source: imported.source,
                visibility: me?.defaultVisibility,
                route: imported.route,
                healthKitUUID: healthId
            )
            context.insert(record)
            byClientId[record.clientId] = record
            knownHealthIds.insert(healthId)
        }

        sync.save()
        commit()
    }

    // MARK: Opnemen

    /// Bewaart een op de iPhone opgenomen workout lokaal en in Gezondheid, en start een sync.
    func saveRecording(_ workout: RecordedWorkout) async -> ActivityRecord {
        var route: [[Double]]?
        if workout.locations.count >= 2 {
            route = RouteSimplifier.payload(
                latitudes: workout.locations.map { $0.coordinate.latitude },
                longitudes: workout.locations.map { $0.coordinate.longitude }
            )
        }
        let hour = Calendar.current.component(.hour, from: workout.start)
        let record = ActivityRecord(
            clientId: workout.clientId,
            type: workout.type,
            title: workout.type.defaultTitle(hour: hour),
            startedAt: workout.start,
            durationSeconds: workout.durationSeconds,
            distanceMeters: workout.distanceMeters,
            elevationGainMeters: workout.elevationGainMeters,
            source: .iphone,
            visibility: me?.defaultVisibility,
            route: route
        )
        context.insert(record)
        sync.save()

        if health.isEnabled, !DemoMode.isActive {
            let healthId = try? await health.saveWorkout(
                clientId: workout.clientId,
                type: workout.type,
                start: workout.start,
                end: workout.end,
                pauses: workout.pauses,
                distanceMeters: workout.distanceMeters,
                locations: workout.locations
            )
            if let healthId {
                record.healthKitUUID = healthId
                sync.save()
            }
        }

        Task {
            await refreshAll()
        }
        return record
    }

    // MARK: Lokale wijzigingen

    /// Markeert een activiteit als gewijzigd zodat de volgende sync hem bijwerkt.
    func markEdited(_ record: ActivityRecord) {
        record.updatedAt = Date()
        if record.syncState == .synced {
            record.syncState = record.serverId == nil ? .pendingUpload : .pendingUpdate
        }
        sync.save()
        Task {
            await refreshAll()
        }
    }

    /// Verwijdert een activiteit; de sync haalt hem daarna van de server.
    func delete(_ record: ActivityRecord) {
        record.syncState = .pendingDelete
        sync.save()
        Task {
            await refreshAll()
        }
    }

    // MARK: Watch

    private func handleWatchWorkout(_ payload: WatchWorkoutPayload) {
        // Niet ingelogd: de workout staat ook in Gezondheid en komt na het inloggen via de import binnen.
        guard me != nil else { return }
        let clientId = ClientID.normalize(payload.clientId)
        let healthId = payload.healthKitUUID?.lowercased()

        if let existing = sync.allRecords().first(where: { $0.clientId == clientId }) {
            if existing.healthKitUUID == nil {
                existing.healthKitUUID = healthId
                sync.save()
            }
            return
        }

        let hour = Calendar.current.component(.hour, from: payload.startedAt)
        let record = ActivityRecord(
            clientId: clientId,
            type: payload.type,
            title: payload.type.defaultTitle(hour: hour),
            startedAt: payload.startedAt,
            durationSeconds: payload.durationSeconds,
            distanceMeters: payload.distanceMeters,
            activeEnergyKcal: payload.activeEnergyKcal,
            avgHeartRate: payload.avgHeartRate,
            maxHeartRate: payload.maxHeartRate,
            source: .watch,
            visibility: me?.defaultVisibility,
            healthKitUUID: healthId
        )
        context.insert(record)
        sync.save()
        Task {
            await refreshAll()
        }
    }
}
