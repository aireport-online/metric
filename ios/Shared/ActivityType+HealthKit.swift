import HealthKit
import MetricCore

extension ActivityType {
    /// Het bijbehorende HealthKit-workouttype.
    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .run: return .running
        case .walk: return .walking
        case .hike: return .hiking
        case .ride: return .cycling
        case .swim: return .swimming
        case .strength: return .traditionalStrengthTraining
        case .hiit: return .highIntensityIntervalTraining
        case .yoga: return .yoga
        case .rowing: return .rowing
        case .football: return .soccer
        case .tennis: return .tennis
        case .other: return .other
        }
    }

    /// Vertaalt een HealthKit-workout (ook van andere apps) naar een Metric-sporttype.
    init(healthKitType: HKWorkoutActivityType) {
        switch healthKitType {
        case .running: self = .run
        case .walking: self = .walk
        case .hiking: self = .hike
        case .cycling: self = .ride
        case .swimming: self = .swim
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: self = .strength
        case .highIntensityIntervalTraining, .crossTraining: self = .hiit
        case .yoga, .pilates, .mindAndBody, .flexibility: self = .yoga
        case .rowing: self = .rowing
        case .soccer: self = .football
        case .tennis: self = .tennis
        default: self = .other
        }
    }

    /// Het HealthKit-type waarin de afstand van deze sport wordt bijgehouden.
    var distanceQuantityType: HKQuantityType? {
        switch self {
        case .run, .walk, .hike:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .ride:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .swim:
            return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        case .strength, .hiit, .yoga, .rowing, .football, .tennis, .other:
            return nil
        }
    }
}
