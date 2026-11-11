import XCTest
@testable import MetricCore

final class RouteAndStatsTests: XCTestCase {
    // MARK: Route

    func testDownsampleKeepsShortRoutes() {
        let points = [1, 2, 3]
        XCTAssertEqual(RouteSimplifier.downsample(points, maxPoints: 1000), points)
        XCTAssertEqual(RouteSimplifier.downsample([Int](), maxPoints: 10), [])
    }

    func testDownsampleLimitsAndKeepsEndpoints() {
        let points = Array(0..<5000)
        let result = RouteSimplifier.downsample(points)
        XCTAssertEqual(result.count, 1000)
        XCTAssertEqual(result.first, 0)
        XCTAssertEqual(result.last, 4999)
        for index in 1..<result.count {
            XCTAssertGreaterThan(result[index], result[index - 1])
        }
    }

    func testDownsampleJustOverTheLimit() {
        let points = Array(0..<1001)
        let result = RouteSimplifier.downsample(points, maxPoints: 1000)
        XCTAssertEqual(result.count, 1000)
        XCTAssertEqual(result.first, 0)
        XCTAssertEqual(result.last, 1000)
    }

    func testPayloadRoundsAndPairs() {
        let payload = RouteSimplifier.payload(latitudes: [52.37021234567, 52.3705], longitudes: [4.89521234567, 4.8961])
        XCTAssertEqual(payload.count, 2)
        XCTAssertEqual(payload[0][0], 52.370212, accuracy: 0.0000001)
        XCTAssertEqual(payload[0][1], 4.895212, accuracy: 0.0000001)
        XCTAssertEqual(payload[1].count, 2)
    }

    // MARK: Statistieken

    private var utc: Calendar {
        StatsCalculator.mondayCalendar(timeZone: TimeZone(identifier: "UTC")!)
    }

    private func date(_ string: String) -> Date {
        MetricDate.parse(string)!
    }

    private var samples: [ActivitySample] {
        [
            ActivitySample(startedAt: date("2026-11-09T07:00:00Z"), durationSeconds: 1800, distanceMeters: 5000),
            ActivitySample(startedAt: date("2026-11-08T23:00:00Z"), durationSeconds: 600),
            ActivitySample(startedAt: date("2026-11-03T10:00:00Z"), durationSeconds: 1200, distanceMeters: 3000),
            ActivitySample(startedAt: date("2026-10-20T10:00:00Z"), durationSeconds: 900),
        ]
    }

    func testWeekStartsOnMonday() {
        // 11 november 2026 is een woensdag.
        let start = StatsCalculator.weekStart(for: date("2026-11-11T12:00:00Z"), calendar: utc)
        XCTAssertEqual(start, date("2026-11-09T00:00:00Z"))
        let sunday = StatsCalculator.weekStart(for: date("2026-11-08T23:00:00Z"), calendar: utc)
        XCTAssertEqual(sunday, date("2026-11-02T00:00:00Z"))
    }

    func testWeeklyBuckets() {
        let buckets = StatsCalculator.weekly(samples, weeks: 4, now: date("2026-11-11T12:00:00Z"), calendar: utc)
        XCTAssertEqual(buckets.count, 4)
        XCTAssertEqual(buckets.map { $0.weekStart }, [
            date("2026-10-19T00:00:00Z"),
            date("2026-10-26T00:00:00Z"),
            date("2026-11-02T00:00:00Z"),
            date("2026-11-09T00:00:00Z"),
        ])
        XCTAssertEqual(buckets.map { $0.count }, [1, 0, 2, 1])
        XCTAssertEqual(buckets[2].durationSeconds, 1800, accuracy: 0.001)
        XCTAssertEqual(buckets[2].distanceMeters, 3000, accuracy: 0.001)
        XCTAssertEqual(buckets[3].distanceMeters, 5000, accuracy: 0.001)
    }

    func testWeeklyRespectsTimeZone() throws {
        // Zondag 23:30 UTC is in Amsterdam al maandag 00:30.
        let sample = [ActivitySample(startedAt: date("2026-11-08T23:30:00Z"), durationSeconds: 600)]
        let now = date("2026-11-11T12:00:00Z")
        let amsterdam = StatsCalculator.mondayCalendar(timeZone: try XCTUnwrap(TimeZone(identifier: "Europe/Amsterdam")))
        XCTAssertEqual(StatsCalculator.weekly(sample, weeks: 1, now: now, calendar: amsterdam).first?.count, 1)
        XCTAssertEqual(StatsCalculator.weekly(sample, weeks: 1, now: now, calendar: utc).first?.count, 0)
    }

    func testStreak() {
        XCTAssertEqual(StatsCalculator.streakWeeks(samples, now: date("2026-11-11T12:00:00Z"), calendar: utc), 2)
        // Een lege lopende week breekt de streak nog niet…
        XCTAssertEqual(StatsCalculator.streakWeeks(samples, now: date("2026-11-18T12:00:00Z"), calendar: utc), 2)
        // …maar een volledig overgeslagen week wel.
        XCTAssertEqual(StatsCalculator.streakWeeks(samples, now: date("2026-11-25T12:00:00Z"), calendar: utc), 0)
        XCTAssertEqual(StatsCalculator.streakWeeks([], now: date("2026-11-11T12:00:00Z"), calendar: utc), 0)
    }
}
