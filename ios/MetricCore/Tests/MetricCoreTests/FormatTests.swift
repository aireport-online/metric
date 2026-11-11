import XCTest
@testable import MetricCore

final class FormatTests: XCTestCase {
    func testDuration() {
        XCTAssertEqual(Format.duration(0), "0:00")
        XCTAssertEqual(Format.duration(59.6), "1:00")
        XCTAssertEqual(Format.duration(1820), "30:20")
        XCTAssertEqual(Format.duration(3723), "1:02:03")
        XCTAssertEqual(Format.duration(-5), "0:00")
    }

    func testDurationShort() {
        XCTAssertEqual(Format.durationShort(1820), "30 min")
        XCTAssertEqual(Format.durationShort(3600), "1 u")
        XCTAssertEqual(Format.durationShort(5400), "1 u 30 min")
        XCTAssertEqual(Format.durationShort(20), "0 min")
    }

    func testDistance() {
        XCTAssertEqual(Format.distance(850), "850 m")
        XCTAssertEqual(Format.distance(999.6), "1,00 km")
        XCTAssertEqual(Format.distance(5230.4), "5,23 km")
        XCTAssertEqual(Format.distance(42200), "42,20 km")
        XCTAssertEqual(Format.distance(123456), "123,5 km")
        XCTAssertEqual(Format.kilometers(10000), "10,00")
    }

    func testPace() {
        XCTAssertEqual(Format.pace(distanceMeters: 5000, durationSeconds: 1500), "5:00 /km")
        XCTAssertEqual(Format.pace(distanceMeters: 5230.4, durationSeconds: 1820), "5:48 /km")
        XCTAssertNil(Format.pace(distanceMeters: 10, durationSeconds: 60))
        XCTAssertNil(Format.pace(distanceMeters: 5000, durationSeconds: 0))
    }

    func testSpeed() {
        XCTAssertEqual(Format.speed(distanceMeters: 30000, durationSeconds: 3600), "30,0 km/u")
        XCTAssertEqual(Format.speed(distanceMeters: 24260, durationSeconds: 3600), "24,3 km/u")
        XCTAssertNil(Format.speed(distanceMeters: 0, durationSeconds: 3600))
    }

    func testPaceOrSpeedDependsOnSport() {
        XCTAssertEqual(Format.paceOrSpeed(type: .ride, distanceMeters: 30000, durationSeconds: 3600), "30,0 km/u")
        XCTAssertEqual(Format.paceOrSpeed(type: .run, distanceMeters: 5000, durationSeconds: 1500), "5:00 /km")
    }

    func testDecimal() {
        XCTAssertEqual(Format.decimal(5.2304, decimals: 2), "5,23")
        XCTAssertEqual(Format.decimal(0.06, decimals: 1), "0,1")
        XCTAssertEqual(Format.decimal(12, decimals: 0), "12")
        XCTAssertEqual(Format.decimal(3.004, decimals: 2), "3,00")
    }

    func testActivityTypeMetadata() {
        XCTAssertEqual(ActivityType.allCases.count, 12)
        XCTAssertEqual(ActivityType.run.displayName, "Hardlopen")
        XCTAssertTrue(ActivityType.ride.isDistanceBased)
        XCTAssertFalse(ActivityType.yoga.isDistanceBased)
        XCTAssertTrue(ActivityType.hike.usesGPS)
        XCTAssertFalse(ActivityType.swim.usesGPS)
        XCTAssertEqual(ActivityType.run.defaultTitle(hour: 7), "Ochtendrun")
        XCTAssertEqual(ActivityType.ride.defaultTitle(hour: 19), "Avondrit")
        for type in ActivityType.allCases {
            XCTAssertFalse(type.symbolName.isEmpty)
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }
}
