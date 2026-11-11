import Foundation

/// Minimale gegevens van een activiteit die nodig zijn voor lokale statistieken.
public struct ActivitySample: Hashable, Sendable {
    public let startedAt: Date
    public let durationSeconds: Double
    public let distanceMeters: Double?

    public init(startedAt: Date, durationSeconds: Double, distanceMeters: Double? = nil) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
    }
}

public struct WeekBucket: Identifiable, Hashable, Sendable {
    /// Maandag 00:00 in de gekozen tijdzone.
    public let weekStart: Date
    public var durationSeconds: Double
    public var distanceMeters: Double
    public var count: Int

    public var id: Date { weekStart }

    public init(weekStart: Date, durationSeconds: Double = 0, distanceMeters: Double = 0, count: Int = 0) {
        self.weekStart = weekStart
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.count = count
    }
}

/// Berekent weekvoortgang en streaks lokaal, zodat de app ook offline klopt.
/// De definities zijn dezelfde als die van `GET /stats` (weken beginnen op maandag).
public enum StatsCalculator {
    public static func mondayCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func weekStart(for date: Date, calendar: Calendar) -> Date {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval.start
        }
        return calendar.startOfDay(for: date)
    }

    /// Precies `weeks` weken, van oud naar nieuw, inclusief lege weken en de lopende week.
    public static func weekly(
        _ samples: [ActivitySample],
        weeks: Int,
        now: Date = Date(),
        calendar: Calendar = StatsCalculator.mondayCalendar()
    ) -> [WeekBucket] {
        guard weeks > 0 else { return [] }
        let currentStart = weekStart(for: now, calendar: calendar)
        var buckets: [WeekBucket] = []
        var offset = weeks - 1
        while offset >= 0 {
            if let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentStart) {
                buckets.append(WeekBucket(weekStart: start))
            }
            offset -= 1
        }
        var indexByStart: [Date: Int] = [:]
        for (index, bucket) in buckets.enumerated() {
            indexByStart[bucket.weekStart] = index
        }
        for sample in samples {
            let start = weekStart(for: sample.startedAt, calendar: calendar)
            guard let index = indexByStart[start] else { continue }
            buckets[index].durationSeconds += sample.durationSeconds
            buckets[index].distanceMeters += sample.distanceMeters ?? 0
            buckets[index].count += 1
        }
        return buckets
    }

    /// Aantal aaneengesloten weken met minstens één activiteit. De lopende week telt mee
    /// zodra er een activiteit is, maar breekt de streak nog niet als hij leeg is.
    public static func streakWeeks(
        _ samples: [ActivitySample],
        now: Date = Date(),
        calendar: Calendar = StatsCalculator.mondayCalendar()
    ) -> Int {
        var activeWeeks = Set<Date>()
        for sample in samples {
            activeWeeks.insert(weekStart(for: sample.startedAt, calendar: calendar))
        }
        var cursor = weekStart(for: now, calendar: calendar)
        if !activeWeeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var streak = 0
        while activeWeeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
