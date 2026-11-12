import Foundation

/// De demo-modus voor de UI-tests die de demovideo's opnemen (`MetricUITests`, `MetricWatchUITests`).
///
/// Staat alleen aan met het startargument `-UITestDemo`; zonder dat argument doet geen van de
/// haken iets. Wat de modus verandert:
///
/// - iPhone: de app begint leeg op het inlogscherm (sessie, instellingen en lokale activiteiten
///   worden bij het starten gewist) en vraagt geen toegang tot Gezondheid en bewaart er niets in.
///   Bij het opnemen gebruikt de app een eenvoudige locatiesessie op de voorgrond (grove
///   nauwkeurigheid, zonder fitness-afstelling, afstandsfilter en achtergrondsessie), omdat de
///   simulator anders alleen de eerste positie van een gesimuleerde route doorgeeft. Inloggen,
///   synchroniseren, de feed, kudos en het opnemen zelf (tijd, afstand, tempo, route) lopen via
///   de gewone code.
/// - Watch: geen HealthKit en geen WatchConnectivity. De workout loopt op een timer met
///   voorbeeldwaarden en het startscherm toont een voorbeeldweek, omdat de Watch zijn
///   voortgang normaal van de iPhone krijgt.
enum DemoMode {
    static let launchArgument = "-UITestDemo"

    static let isActive = ProcessInfo.processInfo.arguments.contains(launchArgument)
}
