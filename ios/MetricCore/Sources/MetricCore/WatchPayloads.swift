import Foundation

/// Een afgeronde workout die de Watch via `WCSession.transferUserInfo` naar de iPhone stuurt.
public struct WatchWorkoutPayload: Codable, Hashable, Sendable {
    public var clientId: String
    public var type: ActivityType
    public var startedAt: Date
    public var durationSeconds: Double
    public var distanceMeters: Double?
    public var activeEnergyKcal: Double?
    public var avgHeartRate: Double?
    public var maxHeartRate: Double?
    /// UUID van de `HKWorkout` op de Watch, als het opslaan in Gezondheid gelukt is.
    public var healthKitUUID: String?

    public init(
        clientId: String,
        type: ActivityType,
        startedAt: Date,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        activeEnergyKcal: Double? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        healthKitUUID: String? = nil
    ) {
        self.clientId = clientId
        self.type = type
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.activeEnergyKcal = activeEnergyKcal
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.healthKitUUID = healthKitUUID
    }

    public static let kind = "workout"

    public func userInfo() -> [String: Any] {
        WatchMessage.dictionary(kind: WatchWorkoutPayload.kind, payload: self)
    }

    public init?(userInfo: [String: Any]) {
        guard let value = WatchMessage.decode(WatchWorkoutPayload.self, kind: WatchWorkoutPayload.kind, from: userInfo) else {
            return nil
        }
        self = value
    }
}

/// De weekvoortgang die de iPhone via `WCSession.updateApplicationContext` naar de Watch stuurt.
public struct WatchContextPayload: Codable, Hashable, Sendable {
    public var isLoggedIn: Bool
    public var displayName: String?
    public var weekMinutes: Int
    public var goalMinutes: Int
    public var streakWeeks: Int
    public var updatedAt: Date

    public init(
        isLoggedIn: Bool,
        displayName: String? = nil,
        weekMinutes: Int = 0,
        goalMinutes: Int = 150,
        streakWeeks: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.isLoggedIn = isLoggedIn
        self.displayName = displayName
        self.weekMinutes = weekMinutes
        self.goalMinutes = goalMinutes
        self.streakWeeks = streakWeeks
        self.updatedAt = updatedAt
    }

    public static let kind = "context"

    public var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return Double(weekMinutes) / Double(goalMinutes)
    }

    public func applicationContext() -> [String: Any] {
        WatchMessage.dictionary(kind: WatchContextPayload.kind, payload: self)
    }

    public init?(applicationContext: [String: Any]) {
        guard let value = WatchMessage.decode(WatchContextPayload.self, kind: WatchContextPayload.kind, from: applicationContext) else {
            return nil
        }
        self = value
    }
}

/// WatchConnectivity accepteert alleen property-list-waarden; we verpakken de payload daarom als JSON-`Data`.
enum WatchMessage {
    static let kindKey = "kind"
    static let payloadKey = "payload"

    static func dictionary<T: Encodable>(kind: String, payload: T) -> [String: Any] {
        var result: [String: Any] = [kindKey: kind]
        if let data = try? MetricCoding.encoder().encode(payload) {
            result[payloadKey] = data
        }
        return result
    }

    static func decode<T: Decodable>(_ type: T.Type, kind: String, from dictionary: [String: Any]) -> T? {
        guard let actualKind = dictionary[kindKey] as? String, actualKind == kind else { return nil }
        guard let data = dictionary[payloadKey] as? Data else { return nil }
        return try? MetricCoding.decoder().decode(type, from: data)
    }
}
