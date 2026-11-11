import Foundation

/// Hulpfuncties voor GPS-routes. De API accepteert maximaal 1000 punten per route.
public enum RouteSimplifier {
    public static let defaultMaxPoints = 1000

    /// Dunt een reeks gelijkmatig uit tot hoogstens `maxPoints`, met behoud van het eerste en laatste punt.
    public static func downsample<T>(_ points: [T], maxPoints: Int = RouteSimplifier.defaultMaxPoints) -> [T] {
        guard points.count > maxPoints else { return points }
        guard maxPoints >= 2 else { return Array(points.prefix(max(0, maxPoints))) }
        let lastIndex = points.count - 1
        var result: [T] = []
        result.reserveCapacity(maxPoints)
        for step in 0..<maxPoints {
            let position = Double(step) * Double(lastIndex) / Double(maxPoints - 1)
            let index = min(lastIndex, Int(position.rounded()))
            result.append(points[index])
        }
        return result
    }

    /// Zet coördinaten om naar het API-formaat `[[lat, lon]]`: uitgedund en afgerond op 6 decimalen (~10 cm).
    public static func payload(latitudes: [Double], longitudes: [Double], maxPoints: Int = RouteSimplifier.defaultMaxPoints) -> [[Double]] {
        let count = min(latitudes.count, longitudes.count)
        var pairs: [[Double]] = []
        pairs.reserveCapacity(count)
        for index in 0..<count {
            pairs.append([round6(latitudes[index]), round6(longitudes[index])])
        }
        return downsample(pairs, maxPoints: maxPoints)
    }

    public static func round6(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }
}
