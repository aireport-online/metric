import Foundation
import Combine
import HealthKit
import MetricCore

/// Beheert een workout op de Watch met `HKWorkoutSession` en `HKLiveWorkoutBuilder`.
final class WorkoutManager: NSObject, ObservableObject {
    let healthStore = HKHealthStore()

    private var session: HKWorkoutSession?
    private(set) var builder: HKLiveWorkoutBuilder?
    private var clientId = ""
    private var startDate = Date()

    /// De sport van de lopende workout, of `nil` als er geen workout loopt.
    @Published private(set) var activeType: ActivityType?
    @Published private(set) var isRunning = false
    @Published private(set) var isEnding = false
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var averageHeartRate: Double = 0
    @Published private(set) var maxHeartRate: Double = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var distance: Double = 0
    /// De samenvatting van de laatst afgeronde workout (tot de gebruiker hem wegtikt).
    @Published var summary: WatchWorkoutPayload?
    @Published var errorMessage: String?

    // Demo-modus (`-UITestDemo`): toestand van de gesimuleerde workout.
    private var demoTimer: Timer?
    private var demoAccumulated: TimeInterval = 0
    private var demoSegmentStart: Date?
    private var demoHeartRateSum: Double = 0
    private var demoHeartRateCount: Double = 0

    private static let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
        .heartRate, .activeEnergyBurned, .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
    ]

    /// Verstreken tijd van de lopende workout (zonder pauzes).
    var elapsedTime: TimeInterval {
        if DemoMode.isActive {
            return demoAccumulated + (demoSegmentStart.map { Date().timeIntervalSince($0) } ?? 0)
        }
        return builder?.elapsedTime ?? 0
    }

    func requestAuthorization() {
        guard !DemoMode.isActive else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType> = [HKObjectType.workoutType()]
        for identifier in WorkoutManager.quantityIdentifiers {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            read.insert(type)
            if identifier != .heartRate {
                share.insert(type)
            }
        }
        healthStore.requestAuthorization(toShare: share, read: read) { _, _ in }
    }

    func start(_ type: ActivityType) {
        guard activeType == nil else { return }
        if DemoMode.isActive {
            startDemo(type)
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type.healthKitType
        configuration.locationType = type.usesGPS ? .outdoor : .indoor
        if type == .swim {
            // Zwembadzwemmen vereist een baanlengte; open water werkt altijd.
            configuration.swimmingLocationType = .openWater
            configuration.locationType = .outdoor
        }

        let session: HKWorkoutSession
        let builder: HKLiveWorkoutBuilder
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session.associatedWorkoutBuilder()
        } catch {
            errorMessage = "De workout kon niet starten. Controleer de toegang tot Gezondheid."
            return
        }

        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        self.session = session
        self.builder = builder
        clientId = ClientID.new()
        startDate = Date()
        resetMetrics()
        summary = nil
        errorMessage = nil
        isEnding = false
        isRunning = true
        activeType = type

        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: clientId]
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { _, _ in
            builder.addMetadata(metadata) { _, _ in }
        }
    }

    func togglePause() {
        if DemoMode.isActive {
            toggleDemoPause()
            return
        }
        if isRunning {
            session?.pause()
        } else {
            session?.resume()
        }
    }

    func end() {
        guard activeType != nil, !isEnding else { return }
        isEnding = true
        if DemoMode.isActive {
            endDemo()
            return
        }
        session?.end()
    }

    private func resetMetrics() {
        heartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        activeEnergy = 0
        distance = 0
    }

    private func update(_ statistics: HKStatistics) {
        let type = statistics.quantityType
        if type == HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let unit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
            averageHeartRate = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
            maxHeartRate = statistics.maximumQuantity()?.doubleValue(for: unit) ?? 0
        } else if type == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        } else if type == HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
                    || type == HKQuantityType.quantityType(forIdentifier: .distanceCycling)
                    || type == HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
        }
    }

    /// Rondt af op de main thread: bouwt de samenvatting en stuurt hem naar de iPhone.
    private func finish(workout: HKWorkout?, endDate: Date) {
        guard let type = activeType else { return }
        let elapsed = elapsedTime
        let duration = workout?.duration ?? (elapsed > 0 ? elapsed : endDate.timeIntervalSince(startDate))
        let payload = WatchWorkoutPayload(
            clientId: clientId,
            type: type,
            startedAt: workout?.startDate ?? startDate,
            durationSeconds: duration,
            distanceMeters: distance > 0 ? distance : nil,
            activeEnergyKcal: activeEnergy > 0 ? activeEnergy : nil,
            avgHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            healthKitUUID: workout?.uuid.uuidString.lowercased()
        )

        // Workouts van een paar seconden (per ongeluk gestart) sturen we niet door.
        if duration >= 10 {
            if !DemoMode.isActive {
                WatchConnectivityManager.shared.send(workout: payload)
            }
            summary = payload
        }

        session = nil
        builder = nil
        activeType = nil
        isRunning = false
        isEnding = false
    }
}

// MARK: - Demo-modus

/// Alleen met het startargument `-UITestDemo` (zie `DemoMode`): de workout loopt op een timer met
/// voorbeeldwaarden, zonder HealthKit. Er wordt niets bewaard of naar de iPhone gestuurd.
extension WorkoutManager {
    private func startDemo(_ type: ActivityType) {
        clientId = ClientID.new()
        startDate = Date()
        resetMetrics()
        demoHeartRateSum = 0
        demoHeartRateCount = 0
        demoAccumulated = 0
        demoSegmentStart = startDate
        summary = nil
        errorMessage = nil
        isEnding = false
        isRunning = true
        activeType = type

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickDemo()
        }
        RunLoop.main.add(timer, forMode: .common)
        demoTimer = timer
        tickDemo()
    }

    private func tickDemo() {
        guard isRunning, let type = activeType else { return }
        let seconds = elapsedTime
        // Hartslag loopt op tijdens de eerste minuut, met een lichte golf.
        heartRate = 126 + min(seconds, 60) * 0.5 + 4 * sin(seconds / 3)
        demoHeartRateSum += heartRate
        demoHeartRateCount += 1
        averageHeartRate = demoHeartRateSum / demoHeartRateCount
        maxHeartRate = max(maxHeartRate, heartRate)
        activeEnergy = seconds * 0.17
        if type.isDistanceBased {
            let metersPerSecond: Double
            switch type {
            case .ride: metersPerSecond = 7.2
            case .swim: metersPerSecond = 0.9
            case .walk, .hike: metersPerSecond = 1.5
            default: metersPerSecond = 3.1
            }
            distance = seconds * metersPerSecond
        }
    }

    private func toggleDemoPause() {
        if isRunning {
            demoAccumulated = elapsedTime
            demoSegmentStart = nil
            isRunning = false
        } else {
            demoSegmentStart = Date()
            isRunning = true
        }
    }

    private func endDemo() {
        if isRunning {
            tickDemo()
        }
        demoAccumulated = elapsedTime
        demoSegmentStart = nil
        demoTimer?.invalidate()
        demoTimer = nil
        // Kort het "Workout opslaan…"-scherm laten zien, zoals bij een echte workout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.finish(workout: nil, endDate: Date())
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            self.isRunning = toState == .running
        }

        guard toState == .ended else { return }
        guard let builder = self.builder else {
            DispatchQueue.main.async {
                self.finish(workout: nil, endDate: date)
            }
            return
        }
        builder.endCollection(withEnd: date) { _, _ in
            builder.finishWorkout { workout, _ in
                DispatchQueue.main.async {
                    self.finish(workout: workout, endDate: date)
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Er ging iets mis met de workout."
            if self.activeType != nil {
                self.finish(workout: nil, endDate: Date())
            }
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            DispatchQueue.main.async {
                self.update(statistics)
            }
        }
    }
}
