import SwiftUI
import MetricCore

// De huisstijl van Metric (zie brand/README.md en brand/tokens.json).
// Gedeeld door de iPhone- en de Watch-app.

extension Color {
    /// Kleur uit een hexwaarde `0xRRGGBB`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    // Ondergronden
    static let bg = Color(hex: 0x0C0E11)
    static let surface = Color(hex: 0x15181D)
    static let surfaceRaised = Color(hex: 0x1E2228)
    static let line = Color(hex: 0x2A2F37)
    static let lineStrong = Color(hex: 0x3A404A)

    // Tekst
    static let text = Color(hex: 0xF4F1EA)
    static let textSecondary = Color(hex: 0xA9AFB8)
    static let textMuted = Color(hex: 0x8A919C)

    // Accenten. Tekst op tartan of volt is altijd inkt.
    static let tartan = Color(hex: 0xF2542D)
    static let tartanLight = Color(hex: 0xFF6A3D)
    static let volt = Color(hex: 0xD4FF3A)
    static let ink = Color(hex: 0x0C0E11)

    // Status: altijd samen met icoon en tekst.
    static let danger = Color(hex: 0xFF5C7A)
    static let warning = Color(hex: 0xFFC247)
    static let success = Color(hex: 0x5BE08A)

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Motion {
        /// Snelle start, rustige uitloop: binnenkomen, baan vullen, cijfers optellen.
        static func sprint(_ duration: Double) -> Animation {
            .timingCurve(0.16, 1, 0.3, 1, duration: duration)
        }

        static let tap = sprint(0.12)
        static let quick = sprint(0.2)
        static let base = sprint(0.32)
        static let slow = sprint(0.52)
        static let count = sprint(0.8)
        static let lap = sprint(0.9)

        /// Doorveren bij kudos en een behaald doel.
        static let kick = Animation.spring(response: 0.32, dampingFraction: 0.55)
        /// Kaarten en sheets.
        static let settle = Animation.spring(response: 0.45, dampingFraction: 0.85)

        /// Vervanging bij "Verminder beweging": alleen een korte fade.
        static let reduced = Animation.easeOut(duration: 0.12)

        static let listStagger: Double = 0.06
        static let laneStagger: Double = 0.08
        static let maxStaggered = 6
    }
}

// MARK: - Typografie

enum MetricTextWeight {
    case regular, medium, semibold

    var fontName: String {
        switch self {
        case .regular: return "InstrumentSans-Regular"
        case .medium: return "InstrumentSans-Medium"
        case .semibold: return "InstrumentSans-SemiBold"
        }
    }
}

extension Font {
    /// Cursief cijfer in Barlow Condensed: ExtraBold vanaf 44 pt, daaronder Bold. Vaste grootte,
    /// zodat grote cijfers binnen hun kaart blijven.
    static func metricNumber(_ size: CGFloat) -> Font {
        .custom(size >= 44 ? "BarlowCondensed-ExtraBoldItalic" : "BarlowCondensed-BoldItalic", fixedSize: size)
    }

    /// Kop in Barlow Condensed Bold.
    static func metricHeading(_ size: CGFloat = 24) -> Font {
        .custom("BarlowCondensed-Bold", size: size, relativeTo: .title2)
    }

    /// Label bij een cijfer, in Barlow Condensed SemiBold.
    static func metricLabel(_ size: CGFloat = 17) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size, relativeTo: .subheadline)
    }

    /// Lopende tekst, knoppen en formulieren in Instrument Sans.
    static func metricText(_ size: CGFloat = 16, weight: MetricTextWeight = .regular) -> Font {
        .custom(weight.fontName, size: size, relativeTo: .body)
    }
}

// MARK: - Sporttinten

extension ActivityType {
    /// Vaste tint per sportfamilie. Alleen voor dunne markeringen en iconen, altijd naast de naam.
    var tint: Color {
        switch self {
        case .run, .walk, .hike: return Theme.tartan
        case .ride: return Theme.volt
        case .swim, .rowing: return Color(hex: 0x68D0F6)
        case .strength, .hiit: return Color(hex: 0xD16CDE)
        case .football, .tennis: return Color(hex: 0x399E78)
        case .yoga: return Color(hex: 0xEAB76C)
        case .other: return Theme.textMuted
        }
    }
}
