import Foundation
import CoreLocation
import HealthKit
import MetricCore

/// Een HealthKit-workout, omgezet naar de gegevens die Metric nodig heeft.
struct ImportedWorkout {
    let healthKitUUID: String
    /// `HKMetadataKeyExternalUUID`: gevuld als de workout door Metric zelf is opgenomen.
    let externalClientId: String?
    let type: ActivityType
    let startedAt: Date
    let durationSeconds: Double
    let distanceMeters: Double?
    let elevationGainMeters: Double?
    let activeEnergyKcal: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let source: ActivitySource
    let route: [[Double]]?
}

private struct AnchoredResult {
    let samples: [HKSample]
    let anchor: HKQueryAnchor?
}

/// Verzamelt de locaties van een `HKWorkoutRouteQuery`, die in meerdere batches binnenkomen.
private final class RouteCollector: @unchecked Sendable {
    var locations: [CLLocation] = []
    var finished = false
}

final class HealthKitService {
    let store = HKHealthStore()

    private let anchorKey = "healthkit.workoutAnchor"
    static let enabledKey = "healthkit.enabled"
    /// Bij de eerste import halen we zoveel dagen geschiedenis op.
    private let initialImportDays = 90

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Of de gebruiker de koppeling met Gezondheid heeft aangezet (HealthKit vertelt niet of lezen is toegestaan).
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: HealthKitService.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: HealthKitService.enabledKey) }
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate, .activeEnergyBurned, .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
        ]
        for identifier in identifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let identifiers: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned, .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
        ]
        for identifier in identifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        return types
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    var canWriteWorkouts: Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    // MARK: Importeren

    func resetAnchor() {
        UserDefaults.standard.removeObject(forKey: anchorKey)
    }

    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor?) {
        guard let anchor else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: anchorKey)
        }
    }

    /// Haalt de workouts op die sinds de vorige keer zijn toegevoegd. Roep `commit` aan zodra ze zijn verwerkt.
    func fetchNewWorkouts() async throws -> (workouts: [HKWorkout], commit: () -> Void) {
        let anchor = loadAnchor()
        let start = Calendar.current.date(byAdding: .day, value: -initialImportDays, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)

        let result: AnchoredResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AnchoredResult, Error>) in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.workoutType(),
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: AnchoredResult(samples: samples ?? [], anchor: newAnchor))
                }
            }
            store.execute(query)
        }

        let workouts = result.samples.compactMap { $0 as? HKWorkout }
        let newAnchor = result.anchor
        return (workouts, { [weak self] in self?.saveAnchor(newAnchor) })
    }

    /// Zet een `HKWorkout` om, inclusief route (voor buitensporten) en hartslag.
    func makeImportedWorkout(from workout: HKWorkout) async -> ImportedWorkout {
        let type = ActivityType(healthKitType: workout.workoutActivityType)
        let external = (workout.metadata?[HKMetadataKeyExternalUUID] as? String).map { ClientID.normalize($0) }

        var route: [[Double]]?
        if type.usesGPS, let locations = try? await routeLocations(for: workout), locations.count >= 2 {
            route = RouteSimplifier.payload(
                latitudes: locations.map { $0.coordinate.latitude },
                longitudes: locations.map { $0.coordinate.longitude }
            )
        }

        let bpm = HKUnit.count().unitDivided(by: .minute())
        var avgHeartRate: Double?
        var maxHeartRate: Double?
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let statistics = workout.statistics(for: heartRateType) {
            avgHeartRate = statistics.averageQuantity()?.doubleValue(for: bpm)
            maxHeartRate = statistics.maximumQuantity()?.doubleValue(for: bpm)
        }

        var energy: Double?
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let statistics = workout.statistics(for: energyType) {
            energy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
        }

        var distance: Double?
        if let distanceType = type.distanceQuantityType, let statistics = workout.statistics(for: distanceType) {
            distance = statistics.sumQuantity()?.doubleValue(for: .meter())
        }

        var elevation: Double?
        if let ascended = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            elevation = ascended.doubleValue(for: .meter())
        }

        let bundleId = workout.sourceRevision.source.bundleIdentifier
        let source: ActivitySource
        if external == nil {
            source = .health
        } else if bundleId.contains("watchkitapp") {
            source = .watch
        } else {
            source = .iphone
        }

        return ImportedWorkout(
            healthKitUUID: workout.uuid.uuidString.lowercased(),
            externalClientId: external,
            type: type,
            startedAt: workout.startDate,
            durationSeconds: workout.duration,
            distanceMeters: distance.flatMap { $0 > 0 ? $0 : nil },
            elevationGainMeters: elevation,
            activeEnergyKcal: energy.flatMap { $0 > 0 ? $0 : nil },
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            source: source,
            route: route
        )
    }

    private func routeLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkoutRoute], Error>) in
            let query = HKAnchoredObjectQuery(
                type: HKSeriesType.workoutRoute(),
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKWorkoutRoute })
                }
            }
            store.execute(query)
        }

        var all: [CLLocation] = []
        for route in routes {
            let segment = try await fetchLocations(of: route)
            all.append(contentsOf: segment)
        }
        return all.sorted { $0.timestamp < $1.timestamp }
    }

    private func fetchLocations(of route: HKWorkoutRoute) async throws -> [CLLocation] {
        let collector = RouteCollector()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CLLocation], Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if collector.finished {
                    return
                }
                if let error {
                    collector.finished = true
                    continuation.resume(throwing: error)
                    return
                }
                if let locations {
                    collector.locations.append(contentsOf: locations)
                }
                if done {
                    collector.finished = true
                    continuation.resume(returning: collector.locations)
                }
            }
            store.execute(query)
        }
    }

    // MARK: Opslaan

    /// Bewaart een op de iPhone opgenomen workout in Gezondheid. Geeft de UUID van de `HKWorkout` terug.
    func saveWorkout(
        clientId: String,
        type: ActivityType,
        start: Date,
        end: Date,
        pauses: [DateInterval],
        distanceMeters: Double?,
        locations: [CLLocation]
    ) async throws -> String? {
        guard canWriteWorkouts else { return nil }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type.healthKitType
        configuration.locationType = type.usesGPS ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await awaitSuccess { builder.beginCollection(withStart: start, completion: $0) }

        if let distanceMeters, distanceMeters > 0, let distanceType = type.distanceQuantityType,
           store.authorizationStatus(for: distanceType) == .sharingAuthorized {
            let sample = HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                start: start,
                end: end
            )
            try await awaitSuccess { builder.add([sample], completion: $0) }
        }

        var events: [HKWorkoutEvent] = []
        for pause in pauses {
            events.append(HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil))
            events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil))
        }
        if !events.isEmpty {
            try await awaitSuccess { builder.addWorkoutEvents(events, completion: $0) }
        }

        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: clientId]
        try await awaitSuccess { builder.addMetadata(metadata, completion: $0) }
        try await awaitSuccess { builder.endCollection(withEnd: end, completion: $0) }

        let workout: HKWorkout? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workout)
                }
            }
        }
        guard let workout else { return nil }

        if locations.count >= 2, store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
            _ = try? await awaitSuccess { routeBuilder.insertRouteData(locations, completion: $0) }
            let _: HKWorkoutRoute? = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkoutRoute?, Error>) in
                routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: route)
                    }
                }
            }
        }

        return workout.uuid.uuidString.lowercased()
    }

    /// Maakt van een HealthKit-completionhandler `(Bool, Error?)` een `async throws`-aanroep.
    private func awaitSuccess(_ body: (@escaping @Sendable (Bool, Error?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            body { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
