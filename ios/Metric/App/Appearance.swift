import UIKit

/// Zet de huisstijl op de UIKit-onderdelen die SwiftUI niet zelf kan kleuren:
/// navigatiebalk, tabbalk en segmentkiezers.
@MainActor
enum Appearance {
    static func apply() {
        let bg = color(0x0C0E11)
        let surface = color(0x15181D)
        let raised = color(0x1E2228)
        let line = color(0x2A2F37)
        let text = color(0xF4F1EA)
        let muted = color(0x8A919C)
        let tartan = color(0xF2542D)
        let ink = color(0x0C0E11)

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = bg
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [
            .foregroundColor: text,
            .font: font("BarlowCondensed-Bold", size: 22, fallbackWeight: .bold),
        ]
        navigation.largeTitleTextAttributes = [
            .foregroundColor: text,
            .font: font("BarlowCondensed-Bold", size: 38, fallbackWeight: .bold),
        ]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = tartan

        let itemFont = font("InstrumentSans-Medium", size: 11, fallbackWeight: .medium)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = muted
        item.normal.titleTextAttributes = [.foregroundColor: muted, .font: itemFont]
        item.selected.iconColor = tartan
        item.selected.titleTextAttributes = [.foregroundColor: tartan, .font: itemFont]

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = surface
        tabBar.shadowColor = line
        tabBar.stackedLayoutAppearance = item
        tabBar.inlineLayoutAppearance = item
        tabBar.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let segmentFont = font("InstrumentSans-Medium", size: 14, fallbackWeight: .medium)
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = tartan
        segmented.backgroundColor = raised
        segmented.setTitleTextAttributes([.foregroundColor: text, .font: segmentFont], for: .normal)
        segmented.setTitleTextAttributes([.foregroundColor: ink, .font: segmentFont], for: .selected)
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func font(_ name: String, size: CGFloat, fallbackWeight: UIFont.Weight) -> UIFont {
        UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: fallbackWeight)
    }
}
