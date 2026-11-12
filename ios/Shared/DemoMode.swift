import Foundation

/// De demo-modus voor de UI-tests die de demovideo's opnemen (`MetricUITests`, `MetricWatchUITests`).
///
/// Staat alleen aan met het startargument `-UITestDemo`; zonder dat argument doet geen van de
/// haken iets. Wat de modus verandert:
///
/// - iPhone: de app begint leeg op het inlogscherm (sessie, instellingen en lokale activiteiten
///   worden bij het starten gewist) en vraagt geen toegang tot Gezondheid en bewaart er niets in.
///   Inloggen, synchroniseren, de feed, kudos en opnemen met GPS lopen via de gewone code.
/// - Watch: geen HealthKit en geen WatchConnectivity. De workout loopt op een timer met
///   voorbeeldwaarden en het startscherm toont een voorbeeldweek, omdat de Watch zijn
///   voortgang normaal van de iPhone krijgt.
enum DemoMode {
    static let launchArgument = "-UITestDemo"

    static let isActive = ProcessInfo.processInfo.arguments.contains(launchArgument)
}
