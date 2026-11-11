import Foundation

/// Sporttypen zoals de API ze kent (`docs/api.md`).
public enum ActivityType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case run, walk, hike, ride, swim, strength, hiit, yoga, rowing, football, tennis, other

    public var id: String { rawValue }

    /// Nederlandse naam voor in de UI.
    public var displayName: String {
        switch self {
        case .run: return "Hardlopen"
        case .walk: return "Wandelen"
        case .hike: return "Hiken"
        case .ride: return "Fietsen"
        case .swim: return "Zwemmen"
        case .strength: return "Krachttraining"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .rowing: return "Roeien"
        case .football: return "Voetbal"
        case .tennis: return "Tennis"
        case .other: return "Overig"
        }
    }

    /// SF Symbol-naam (beschikbaar vanaf iOS 16 / watchOS 9).
    public var symbolName: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .hike: return "figure.hiking"
        case .ride: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .strength: return "figure.strengthtraining.traditional"
        case .hiit: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .rowing: return "figure.rower"
        case .football: return "figure.soccer"
        case .tennis: return "figure.tennis"
        case .other: return "figure.mixed.cardio"
        }
    }

    /// Sporten waarbij afstand de belangrijkste maat is.
    public var isDistanceBased: Bool {
        switch self {
        case .run, .walk, .hike, .ride, .swim, .rowing: return true
        case .strength, .hiit, .yoga, .football, .tennis, .other: return false
        }
    }

    /// Buitensporten waarbij we een GPS-route vastleggen.
    public var usesGPS: Bool {
        switch self {
        case .run, .walk, .hike, .ride: return true
        case .swim, .strength, .hiit, .yoga, .rowing, .football, .tennis, .other: return false
        }
    }

    /// Fietsen tonen we in km/u, de rest in min/km.
    public var prefersSpeed: Bool {
        self == .ride
    }

    /// Standaardtitel op basis van het tijdstip, bv. "Ochtendrun".
    public func defaultTitle(hour: Int) -> String {
        let part: String
        switch hour {
        case 5..<12: part = "Ochtend"
        case 12..<18: part = "Middag"
        case 18..<23: part = "Avond"
        default: part = "Nacht"
        }
        let noun: String
        switch self {
        case .run: noun = "run"
        case .walk: noun = "wandeling"
        case .hike: noun = "hike"
        case .ride: noun = "rit"
        case .swim: noun = "zwemsessie"
        case .strength: noun = "krachttraining"
        case .hiit: noun = "HIIT"
        case .yoga: noun = "yoga"
        case .rowing: noun = "roeisessie"
        case .football: noun = "voetbal"
        case .tennis: noun = "tennis"
        case .other: noun = "workout"
        }
        return part + noun
    }
}

extension ActivityType: Codable {
    /// Onbekende typen (bv. van een nieuwere server) vallen terug op `.other`.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ActivityType(rawValue: raw) ?? .other
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum ActivityVisibility: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case `private`, friends, `public`

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .private: return "Alleen ik"
        case .friends: return "Vrienden"
        case .public: return "Iedereen met de link"
        }
    }

    public var symbolName: String {
        switch self {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .public: return "globe"
        }
    }
}

public enum ActivitySource: String, CaseIterable, Hashable, Sendable {
    case iphone, watch, health, web

    public var displayName: String {
        switch self {
        case .iphone: return "iPhone"
        case .watch: return "Apple Watch"
        case .health: return "Gezondheid"
        case .web: return "Website"
        }
    }
}

extension ActivitySource: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ActivitySource(rawValue: raw) ?? .web
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Client-ID's zijn UUID's in kleine letters, zodat ze gelijk zijn aan wat de server (Postgres) teruggeeft.
public enum ClientID {
    public static func new() -> String {
        UUID().uuidString.lowercased()
    }

    public static func normalize(_ value: String) -> String {
        value.lowercased()
    }
}
