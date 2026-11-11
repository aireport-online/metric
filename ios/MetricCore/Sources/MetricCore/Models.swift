import Foundation

// MARK: - Gebruikers

public struct UserSummary: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let username: String
    public let displayName: String

    public init(id: String, username: String, displayName: String) {
        self.id = id
        self.username = username
        self.displayName = displayName
    }
}

public struct Me: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var username: String
    public var displayName: String
    public var email: String
    public var bio: String
    public var weeklyGoalMinutes: Int
    public var defaultVisibility: ActivityVisibility
    public var createdAt: Date

    public var summary: UserSummary {
        UserSummary(id: id, username: username, displayName: displayName)
    }
}

public struct ProfileUser: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let username: String
    public let displayName: String
    public let bio: String
    public let createdAt: Date
}

public enum Relation: String, Codable, Hashable, Sendable {
    case me = "self"
    case friends
    case outgoing
    case incoming
    case notConnected = "none"
}

// MARK: - Activiteiten

public struct Activity: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let clientId: String
    public let user: UserSummary
    public var type: ActivityType
    public var title: String
    public var notes: String
    public let startedAt: Date
    public let durationSeconds: Double
    public let distanceMeters: Double?
    public let elevationGainMeters: Double?
    public let activeEnergyKcal: Double?
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let source: ActivitySource
    public var visibility: ActivityVisibility
    public let hasRoute: Bool
    /// Alleen gevuld in het detail-antwoord: lijst van `[lat, lon]`.
    public let route: [[Double]]?
    public var kudosCount: Int
    public var commentCount: Int
    public var hasKudoed: Bool
    public let createdAt: Date

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clientId = try c.decode(String.self, forKey: .clientId)
        user = try c.decode(UserSummary.self, forKey: .user)
        type = try c.decode(ActivityType.self, forKey: .type)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
        elevationGainMeters = try c.decodeIfPresent(Double.self, forKey: .elevationGainMeters)
        activeEnergyKcal = try c.decodeIfPresent(Double.self, forKey: .activeEnergyKcal)
        avgHeartRate = try c.decodeIfPresent(Double.self, forKey: .avgHeartRate)
        maxHeartRate = try c.decodeIfPresent(Double.self, forKey: .maxHeartRate)
        source = try c.decodeIfPresent(ActivitySource.self, forKey: .source) ?? .web
        visibility = try c.decodeIfPresent(ActivityVisibility.self, forKey: .visibility) ?? .friends
        hasRoute = try c.decodeIfPresent(Bool.self, forKey: .hasRoute) ?? false
        route = try c.decodeIfPresent([[Double]].self, forKey: .route)
        kudosCount = try c.decodeIfPresent(Int.self, forKey: .kudosCount) ?? 0
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        hasKudoed = try c.decodeIfPresent(Bool.self, forKey: .hasKudoed) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? startedAt
    }
}

/// Body voor `POST /activities` en `POST /activities/batch`. `nil`-velden worden weggelaten.
public struct ActivityInput: Codable, Hashable, Sendable {
    public var clientId: String
    public var type: ActivityType
    public var title: String?
    public var notes: String?
    public var startedAt: Date
    public var durationSeconds: Double
    public var distanceMeters: Double?
    public var elevationGainMeters: Double?
    public var activeEnergyKcal: Double?
    public var avgHeartRate: Double?
    public var maxHeartRate: Double?
    public var source: ActivitySource
    public var visibility: ActivityVisibility?
    public var route: [[Double]]?

    public init(
        clientId: String,
        type: ActivityType,
        title: String? = nil,
        notes: String? = nil,
        startedAt: Date,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        elevationGainMeters: Double? = nil,
        activeEnergyKcal: Double? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        source: ActivitySource,
        visibility: ActivityVisibility? = nil,
        route: [[Double]]? = nil
    ) {
        self.clientId = clientId
        self.type = type
        self.title = title
        self.notes = notes
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.activeEnergyKcal = activeEnergyKcal
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.source = source
        self.visibility = visibility
        self.route = route
    }
}

/// Body voor `PATCH /activities/:id`.
public struct ActivityUpdate: Codable, Hashable, Sendable {
    public var title: String?
    public var notes: String?
    public var visibility: ActivityVisibility?
    public var type: ActivityType?

    public init(title: String? = nil, notes: String? = nil, visibility: ActivityVisibility? = nil, type: ActivityType? = nil) {
        self.title = title
        self.notes = notes
        self.visibility = visibility
        self.type = type
    }
}

public struct Comment: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let user: UserSummary
    public let body: String
    public let createdAt: Date
}

// MARK: - Voortgang

public struct Stats: Codable, Hashable, Sendable {
    public struct ThisWeek: Codable, Hashable, Sendable {
        public let durationSeconds: Double
        public let distanceMeters: Double
        public let activeEnergyKcal: Double
        public let count: Int
        public let goalMinutes: Int
    }

    public struct Week: Codable, Identifiable, Hashable, Sendable {
        /// Maandag van de week, `yyyy-MM-dd`.
        public let weekStart: String
        public let durationSeconds: Double
        public let distanceMeters: Double
        public let count: Int

        public var id: String { weekStart }
    }

    public struct TypeBreakdown: Codable, Identifiable, Hashable, Sendable {
        public let type: ActivityType
        public let count: Int
        public let durationSeconds: Double
        public let distanceMeters: Double

        public var id: String { type.rawValue }
    }

    public let thisWeek: ThisWeek
    public let weekly: [Week]
    public let byType: [TypeBreakdown]
    public let totals: Totals
    public let currentStreakWeeks: Int
}

public struct Totals: Codable, Hashable, Sendable {
    public let count: Int
    public let durationSeconds: Double
    public let distanceMeters: Double
}

public enum LeaderboardMetric: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case duration, distance, count

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .duration: return "Tijd"
        case .distance: return "Afstand"
        case .count: return "Aantal"
        }
    }
}

public struct Leaderboard: Codable, Hashable, Sendable {
    public struct Entry: Codable, Identifiable, Hashable, Sendable {
        public let rank: Int
        public let user: UserSummary
        public let value: Double
        public let count: Int
        public let isMe: Bool

        public var id: String { user.id }
    }

    public let metric: String
    public let weekStart: String
    public let entries: [Entry]
}

// MARK: - Vrienden

public struct FriendRequest: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let user: UserSummary
    public let createdAt: Date
}

public struct UserSearchResult: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let username: String
    public let displayName: String
    public var relation: Relation

    public var summary: UserSummary {
        UserSummary(id: id, username: username, displayName: displayName)
    }
}

public struct Profile: Codable, Hashable, Sendable {
    public let user: ProfileUser
    public var relation: Relation
    public var requestId: String?
    public let stats: Totals
    public let activities: [Activity]
}

// MARK: - Antwoorden en bodies

public struct AuthResponse: Codable, Sendable {
    public let token: String
    public let user: Me
}

public struct MeResponse: Codable, Sendable {
    public let user: Me
}

public struct ActivitiesPage: Codable, Sendable {
    public let activities: [Activity]
    public let nextCursor: String?
}

public struct ActivityResponse: Codable, Sendable {
    public let activity: Activity
}

public struct ActivitiesResponse: Codable, Sendable {
    public let activities: [Activity]
}

public struct ActivityDetailResponse: Codable, Sendable {
    public let activity: Activity
    public let comments: [Comment]
}

public struct KudosResponse: Codable, Sendable {
    public let kudosCount: Int
    public let hasKudoed: Bool
}

public struct CommentResponse: Codable, Sendable {
    public let comment: Comment
}

public struct FriendsResponse: Codable, Sendable {
    public let friends: [UserSummary]
    public let incoming: [FriendRequest]
    public let outgoing: [FriendRequest]
}

public struct FriendStatusResponse: Codable, Sendable {
    /// `requested` of `friends`.
    public let status: String
}

public struct UserSearchResponse: Codable, Sendable {
    public let users: [UserSearchResult]
}

public struct MeUpdate: Codable, Hashable, Sendable {
    public var displayName: String?
    public var bio: String?
    public var weeklyGoalMinutes: Int?
    public var defaultVisibility: ActivityVisibility?

    public init(displayName: String? = nil, bio: String? = nil, weeklyGoalMinutes: Int? = nil, defaultVisibility: ActivityVisibility? = nil) {
        self.displayName = displayName
        self.bio = bio
        self.weeklyGoalMinutes = weeklyGoalMinutes
        self.defaultVisibility = defaultVisibility
    }
}
