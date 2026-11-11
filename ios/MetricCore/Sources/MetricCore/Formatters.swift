import Foundation

/// Nederlandse weergave van duur, afstand, tempo en snelheid. Bewust locale-onafhankelijk,
/// zodat de uitvoer overal hetzelfde is (en testbaar).
public enum Format {
    /// `30:20` of `1:02:03`.
    public static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(pad(minutes)):\(pad(secs))"
        }
        return "\(minutes):\(pad(secs))"
    }

    /// `45 min`, `1 u` of `1 u 30 min`.
    public static func durationShort(_ seconds: Double) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours) u \(minutes) min"
        }
        if hours > 0 {
            return "\(hours) u"
        }
        return "\(minutes) min"
    }

    /// `850 m`, `5,23 km` of `123,5 km`.
    public static func distance(_ meters: Double) -> String {
        let rounded = max(0, meters).rounded()
        if rounded < 1000 {
            return "\(Int(rounded)) m"
        }
        return kilometers(meters) + " km"
    }

    /// Alleen het getal in kilometers: `5,23`.
    public static func kilometers(_ meters: Double) -> String {
        let km = max(0, meters) / 1000
        return decimal(km, decimals: km >= 100 ? 1 : 2)
    }

    /// Tempo in min/km: `5:48 /km`. `nil` als er te weinig afstand is.
    public static func pace(distanceMeters: Double, durationSeconds: Double) -> String? {
        guard distanceMeters >= 50, durationSeconds > 0 else { return nil }
        let secondsPerKm = durationSeconds / (distanceMeters / 1000)
        guard secondsPerKm.isFinite, secondsPerKm < 3600 else { return nil }
        let total = Int(secondsPerKm.rounded())
        return "\(total / 60):\(pad(total % 60)) /km"
    }

    /// Snelheid in km/u: `24,3 km/u`.
    public static func speed(distanceMeters: Double, durationSeconds: Double) -> String? {
        guard distanceMeters > 0, durationSeconds > 0 else { return nil }
        let kmh = (distanceMeters / 1000) / (durationSeconds / 3600)
        guard kmh.isFinite else { return nil }
        return decimal(kmh, decimals: 1) + " km/u"
    }

    /// Tempo of snelheid, afhankelijk van de sport.
    public static func paceOrSpeed(type: ActivityType, distanceMeters: Double, durationSeconds: Double) -> String? {
        if type.prefersSpeed {
            return speed(distanceMeters: distanceMeters, durationSeconds: durationSeconds)
        }
        return pace(distanceMeters: distanceMeters, durationSeconds: durationSeconds)
    }

    /// Getal met een komma als decimaalteken.
    public static func decimal(_ value: Double, decimals: Int) -> String {
        let factor = pow(10.0, Double(decimals))
        let scaled = Int((abs(value) * factor).rounded())
        let whole = scaled / Int(factor)
        let fraction = scaled % Int(factor)
        let sign = value < 0 && scaled != 0 ? "-" : ""
        if decimals <= 0 {
            return "\(sign)\(whole)"
        }
        var fractionString = String(fraction)
        while fractionString.count < decimals {
            fractionString = "0" + fractionString
        }
        return "\(sign)\(whole),\(fractionString)"
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
