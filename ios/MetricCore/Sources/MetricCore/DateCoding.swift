import Foundation

/// ISO 8601-datums zoals de API ze gebruikt. Accepteert zowel mét als zonder fractionele seconden.
public enum MetricDate {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public static func parse(_ string: String) -> Date? {
        if let date = withFraction.date(from: string) {
            return date
        }
        return withoutFraction.date(from: string)
    }

    /// Altijd UTC met milliseconden: `2026-11-11T07:30:00.000Z`.
    public static func string(from date: Date) -> String {
        withFraction.string(from: date)
    }
}

public enum MetricCoding {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = MetricDate.parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Ongeldige ISO 8601-datum: \(string)"
                )
            }
            return date
        }
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(MetricDate.string(from: date))
        }
        return encoder
    }
}
