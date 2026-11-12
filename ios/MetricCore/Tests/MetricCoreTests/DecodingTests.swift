import XCTest
@testable import MetricCore

final class DecodingTests: XCTestCase {
    private let activityJSON = """
    {
      "id": "3f1c2a52-6a57-4c53-8a59-0d9d1d4a8f10",
      "clientId": "9b2e7c1e-0f5d-4b62-9a53-6f0a1f0b7c11",
      "user": { "id": "u1", "username": "sam", "displayName": "Sam" },
      "type": "run",
      "title": "Ochtendrun",
      "notes": "",
      "startedAt": "2026-11-11T07:30:00.000Z",
      "durationSeconds": 1820,
      "distanceMeters": 5230.4,
      "elevationGainMeters": 31,
      "activeEnergyKcal": 412,
      "avgHeartRate": 152,
      "maxHeartRate": 178,
      "source": "watch",
      "visibility": "friends",
      "hasRoute": true,
      "route": [[52.3702, 4.8952], [52.3705, 4.8961]],
      "kudosCount": 3,
      "commentCount": 1,
      "hasKudoed": false,
      "createdAt": "2026-11-11T08:01:02Z"
    }
    """

    func testDecodesActivityFromContract() throws {
        let activity = try MetricCoding.decoder().decode(Activity.self, from: Data(activityJSON.utf8))
        XCTAssertEqual(activity.type, .run)
        XCTAssertEqual(activity.title, "Ochtendrun")
        XCTAssertEqual(activity.user.username, "sam")
        XCTAssertEqual(activity.durationSeconds, 1820)
        XCTAssertEqual(activity.distanceMeters ?? 0, 5230.4, accuracy: 0.001)
        XCTAssertEqual(activity.source, .watch)
        XCTAssertEqual(activity.visibility, .friends)
        XCTAssertTrue(activity.hasRoute)
        XCTAssertEqual(activity.route?.count, 2)
        XCTAssertEqual(activity.kudosCount, 3)
        XCTAssertFalse(activity.hasKudoed)
        XCTAssertEqual(activity.startedAt, MetricDate.parse("2026-11-11T07:30:00Z"))
    }

    func testDecodesActivityWithNullsAndUnknownType() throws {
        let json = """
        {
          "id": "a", "clientId": "b",
          "user": { "id": "u1", "username": "sam", "displayName": "Sam" },
          "type": "kitesurfen",
          "title": "Sessie", "notes": "",
          "startedAt": "2026-11-11T07:30:00Z",
          "durationSeconds": 600.5,
          "distanceMeters": null, "elevationGainMeters": null, "activeEnergyKcal": null,
          "avgHeartRate": null, "maxHeartRate": null,
          "source": "web", "visibility": "private", "hasRoute": false,
          "kudosCount": 0, "commentCount": 0, "hasKudoed": false,
          "createdAt": "2026-11-11T07:45:00.123Z"
        }
        """
        let activity = try MetricCoding.decoder().decode(Activity.self, from: Data(json.utf8))
        XCTAssertEqual(activity.type, .other)
        XCTAssertNil(activity.distanceMeters)
        XCTAssertNil(activity.avgHeartRate)
        XCTAssertNil(activity.route)
        XCTAssertEqual(activity.visibility, .private)
        XCTAssertEqual(activity.durationSeconds, 600.5, accuracy: 0.0001)
    }

    func testDateParsingWithAndWithoutFractionalSeconds() {
        let withFraction = MetricDate.parse("2026-11-11T07:30:00.000Z")
        let withoutFraction = MetricDate.parse("2026-11-11T07:30:00Z")
        XCTAssertNotNil(withFraction)
        XCTAssertEqual(withFraction, withoutFraction)
        XCTAssertNil(MetricDate.parse("gisteren"))
        XCTAssertEqual(MetricDate.string(from: withoutFraction!), "2026-11-11T07:30:00.000Z")
    }

    func testDecodesStats() throws {
        let json = """
        {
          "thisWeek": { "durationSeconds": 5400, "distanceMeters": 15200, "activeEnergyKcal": 1210, "count": 3, "goalMinutes": 150 },
          "weekly": [ { "weekStart": "2026-11-09", "durationSeconds": 5400, "distanceMeters": 15200, "count": 3 } ],
          "byType": [ { "type": "run", "count": 9, "durationSeconds": 16200, "distanceMeters": 45100 } ],
          "totals": { "count": 120, "durationSeconds": 310000, "distanceMeters": 890000 },
          "currentStreakWeeks": 4
        }
        """
        let stats = try MetricCoding.decoder().decode(Stats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.thisWeek.goalMinutes, 150)
        XCTAssertEqual(stats.weekly.first?.weekStart, "2026-11-09")
        XCTAssertEqual(stats.byType.first?.type, .run)
        XCTAssertEqual(stats.totals.count, 120)
        XCTAssertEqual(stats.currentStreakWeeks, 4)
    }

    func testDecodesProfileAndRelation() throws {
        let json = """
        {
          "user": { "id": "u2", "username": "sanne", "displayName": "Sanne", "bio": "", "createdAt": "2026-01-01T00:00:00.000Z" },
          "relation": "none",
          "requestId": null,
          "stats": { "count": 1, "durationSeconds": 60, "distanceMeters": 0 },
          "activities": []
        }
        """
        let profile = try MetricCoding.decoder().decode(Profile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.relation, .notConnected)
        XCTAssertNil(profile.requestId)
        XCTAssertEqual(profile.user.username, "sanne")

        let selfRelation = try MetricCoding.decoder().decode([Relation].self, from: Data("[\"self\", \"incoming\"]".utf8))
        XCTAssertEqual(selfRelation, [.me, .incoming])
    }

    func testEncodesActivityInputWithoutNilFields() throws {
        let startedAt = try XCTUnwrap(MetricDate.parse("2026-11-11T07:30:00Z"))
        let input = ActivityInput(
            clientId: "9b2e7c1e-0f5d-4b62-9a53-6f0a1f0b7c11",
            type: .ride,
            startedAt: startedAt,
            durationSeconds: 3600,
            distanceMeters: 30000,
            source: .iphone
        )
        let data = try MetricCoding.encoder().encode(input)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "ride")
        XCTAssertEqual(object["source"] as? String, "iphone")
        XCTAssertEqual(object["startedAt"] as? String, "2026-11-11T07:30:00.000Z")
        XCTAssertEqual(object["durationSeconds"] as? Double, 3600)
        XCTAssertNil(object["title"])
        XCTAssertNil(object["route"])
        XCTAssertNil(object["visibility"])
        XCTAssertNil(object["avgHeartRate"])
    }

    func testDecodesServerError() {
        let data = Data("""
        { "error": { "code": "invalid_credentials", "message": "E-mailadres of wachtwoord klopt niet." } }
        """.utf8)
        let error = APIError.from(status: 401, data: data)
        XCTAssertEqual(error, .server(status: 401, code: "invalid_credentials", message: "E-mailadres of wachtwoord klopt niet."))
        XCTAssertTrue(error.isUnauthorized)
        XCTAssertEqual(error.errorDescription, "E-mailadres of wachtwoord klopt niet.")

        let fallback = APIError.from(status: 500, data: Data("<html>".utf8))
        XCTAssertEqual(fallback.code, "unknown")
        XCTAssertFalse(fallback.isUnauthorized)
    }

    func testBuildsRequestWithTokenAndQuery() throws {
        let client = APIClient(baseURL: try XCTUnwrap(URL(string: "http://localhost:3000")), token: "abc")
        let request = try client.makeRequest(
            method: "GET",
            path: "/activities",
            query: [URLQueryItem(name: "limit", value: "20")]
        )
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3000/api/v1/activities?limit=20")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))

        let post = try client.makeRequest(method: "POST", path: "/auth/login", body: Data("{}".utf8))
        XCTAssertEqual(post.url?.absoluteString, "http://localhost:3000/api/v1/auth/login")
        XCTAssertEqual(post.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testWatchPayloadRoundTrip() throws {
        let startedAt = try XCTUnwrap(MetricDate.parse("2026-11-11T07:30:00.250Z"))
        let workout = WatchWorkoutPayload(
            clientId: ClientID.new(),
            type: .run,
            startedAt: startedAt,
            durationSeconds: 1820,
            distanceMeters: 5230.4,
            activeEnergyKcal: 412,
            avgHeartRate: 152,
            maxHeartRate: 178
        )
        let decoded = try XCTUnwrap(WatchWorkoutPayload(userInfo: workout.userInfo()))
        XCTAssertEqual(decoded, workout)
        XCTAssertEqual(workout.clientId, workout.clientId.lowercased())

        let context = WatchContextPayload(
            isLoggedIn: true, displayName: "Sam", weekMinutes: 90, goalMinutes: 150, streakWeeks: 4, updatedAt: startedAt
        )
        let decodedContext = try XCTUnwrap(WatchContextPayload(applicationContext: context.applicationContext()))
        XCTAssertEqual(decodedContext, context)
        XCTAssertEqual(decodedContext.progress, 0.6, accuracy: 0.0001)

        // Een context is geen workout en andersom.
        XCTAssertNil(WatchWorkoutPayload(userInfo: context.applicationContext()))
        XCTAssertNil(WatchContextPayload(applicationContext: [:]))
    }
}
