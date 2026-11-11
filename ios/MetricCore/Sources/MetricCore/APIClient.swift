import Foundation

public enum APIError: Error, Equatable, Sendable {
    /// De server gaf een foutantwoord (`{ "error": { code, message } }`).
    case server(status: Int, code: String, message: String)
    /// Geen verbinding, time-out, enz.
    case network(String)
    /// Het antwoord kon niet gelezen worden.
    case decoding(String)
    case invalidResponse

    public var isUnauthorized: Bool {
        if case .server(let status, _, _) = self {
            return status == 401
        }
        return false
    }

    public var isNotFound: Bool {
        if case .server(let status, _, _) = self {
            return status == 404
        }
        return false
    }

    public var isNetwork: Bool {
        if case .network = self {
            return true
        }
        return false
    }

    public var code: String? {
        if case .server(_, let code, _) = self {
            return code
        }
        return nil
    }

    /// Zet een niet-2xx antwoord om naar een `APIError`.
    public static func from(status: Int, data: Data) -> APIError {
        struct Envelope: Decodable {
            struct Body: Decodable {
                let code: String?
                let message: String?
            }
            let error: Body
        }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return .server(
                status: status,
                code: envelope.error.code ?? "unknown",
                message: envelope.error.message ?? "Er ging iets mis (\(status))."
            )
        }
        return .server(status: status, code: "unknown", message: "Er ging iets mis (\(status)).")
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .server(_, _, let message):
            return message
        case .network:
            return "Geen verbinding met de server. Controleer je internetverbinding."
        case .decoding:
            return "Het antwoord van de server kon niet gelezen worden."
        case .invalidResponse:
            return "Onverwacht antwoord van de server."
        }
    }
}

/// Dunne async/await-client voor de Metric API (`docs/api.md`).
public final class APIClient: @unchecked Sendable {
    public var baseURL: URL
    public var token: String?

    private let session: URLSession
    private let decoder = MetricCoding.decoder()
    private let encoder = MetricCoding.encoder()

    public init(baseURL: URL, token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    // MARK: Account

    public func register(email: String, password: String, username: String, displayName: String) async throws -> AuthResponse {
        struct Body: Encodable {
            let email: String
            let password: String
            let username: String
            let displayName: String
        }
        let body = Body(email: email, password: password, username: username, displayName: displayName)
        return try await send("POST", "/auth/register", body: body)
    }

    public func login(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        return try await send("POST", "/auth/login", body: Body(email: email, password: password))
    }

    public func logout() async throws {
        try await sendVoid("POST", "/auth/logout")
    }

    public func me() async throws -> Me {
        let response: MeResponse = try await send("GET", "/me")
        return response.user
    }

    public func updateMe(_ update: MeUpdate) async throws -> Me {
        let response: MeResponse = try await send("PATCH", "/me", body: update)
        return response.user
    }

    public func deleteAccount(password: String) async throws {
        struct Body: Encodable {
            let password: String
        }
        try await sendVoid("DELETE", "/me", body: Body(password: password))
    }

    // MARK: Activiteiten

    public func activities(before: String? = nil, limit: Int = 50) async throws -> ActivitiesPage {
        try await send("GET", "/activities", query: pageQuery(before: before, limit: limit))
    }

    public func uploadActivity(_ input: ActivityInput) async throws -> Activity {
        let response: ActivityResponse = try await send("POST", "/activities", body: input)
        return response.activity
    }

    public func uploadActivities(_ inputs: [ActivityInput]) async throws -> [Activity] {
        struct Body: Encodable {
            let activities: [ActivityInput]
        }
        let response: ActivitiesResponse = try await send("POST", "/activities/batch", body: Body(activities: inputs))
        return response.activities
    }

    public func activityDetail(id: String) async throws -> ActivityDetailResponse {
        try await send("GET", "/activities/\(id)")
    }

    public func updateActivity(id: String, _ update: ActivityUpdate) async throws -> Activity {
        let response: ActivityResponse = try await send("PATCH", "/activities/\(id)", body: update)
        return response.activity
    }

    public func deleteActivity(id: String) async throws {
        try await sendVoid("DELETE", "/activities/\(id)")
    }

    public func giveKudos(activityId: String) async throws -> KudosResponse {
        try await send("POST", "/activities/\(activityId)/kudos")
    }

    public func removeKudos(activityId: String) async throws -> KudosResponse {
        try await send("DELETE", "/activities/\(activityId)/kudos")
    }

    public func addComment(activityId: String, body: String) async throws -> Comment {
        struct Body: Encodable {
            let body: String
        }
        let response: CommentResponse = try await send("POST", "/activities/\(activityId)/comments", body: Body(body: body))
        return response.comment
    }

    public func deleteComment(id: String) async throws {
        try await sendVoid("DELETE", "/comments/\(id)")
    }

    // MARK: Feed en voortgang

    public func feed(before: String? = nil, limit: Int = 30) async throws -> ActivitiesPage {
        try await send("GET", "/feed", query: pageQuery(before: before, limit: limit))
    }

    public func stats(weeks: Int = 12, timeZone: TimeZone = .current) async throws -> Stats {
        let query = [
            URLQueryItem(name: "weeks", value: String(weeks)),
            URLQueryItem(name: "tz", value: timeZone.identifier),
        ]
        return try await send("GET", "/stats", query: query)
    }

    public func leaderboard(metric: LeaderboardMetric = .duration, timeZone: TimeZone = .current) async throws -> Leaderboard {
        let query = [
            URLQueryItem(name: "metric", value: metric.rawValue),
            URLQueryItem(name: "tz", value: timeZone.identifier),
        ]
        return try await send("GET", "/leaderboard", query: query)
    }

    // MARK: Vrienden

    public func friends() async throws -> FriendsResponse {
        try await send("GET", "/friends")
    }

    public func sendFriendRequest(username: String) async throws -> FriendStatusResponse {
        struct Body: Encodable {
            let username: String
        }
        return try await send("POST", "/friends/requests", body: Body(username: username))
    }

    public func acceptFriendRequest(id: String) async throws -> FriendStatusResponse {
        try await send("POST", "/friends/requests/\(id)/accept")
    }

    public func deleteFriendRequest(id: String) async throws {
        try await sendVoid("DELETE", "/friends/requests/\(id)")
    }

    public func removeFriend(userId: String) async throws {
        try await sendVoid("DELETE", "/friends/\(userId)")
    }

    public func searchUsers(query: String) async throws -> [UserSearchResult] {
        let response: UserSearchResponse = try await send(
            "GET", "/users/search", query: [URLQueryItem(name: "q", value: query)]
        )
        return response.users
    }

    public func profile(username: String) async throws -> Profile {
        try await send("GET", "/users/\(username)")
    }

    // MARK: Transport

    /// Bouwt het verzoek op. `internal` zodat de tests het kunnen controleren.
    func makeRequest(method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("api/v1" + path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let finalURL = components.url else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func pageQuery(before: String?, limit: Int) -> [URLQueryItem] {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let before, !before.isEmpty {
            query.append(URLQueryItem(name: "before", value: before))
        }
        return query
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.from(status: http.statusCode, data: data)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func send<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = []) async throws -> T {
        let request = try makeRequest(method: method, path: path, query: query)
        let data = try await perform(request)
        return try decode(data)
    }

    private func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B) async throws -> T {
        let payload = try encoder.encode(body)
        let request = try makeRequest(method: method, path: path, body: payload)
        let data = try await perform(request)
        return try decode(data)
    }

    private func sendVoid(_ method: String, _ path: String) async throws {
        let request = try makeRequest(method: method, path: path)
        _ = try await perform(request)
    }

    private func sendVoid<B: Encodable>(_ method: String, _ path: String, body: B) async throws {
        let payload = try encoder.encode(body)
        let request = try makeRequest(method: method, path: path, body: payload)
        _ = try await perform(request)
    }
}
