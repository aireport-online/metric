import CoreLocation
import XCTest

/// Loopt de iPhone-app door voor de demovideo: inloggen, Vandaag, Activiteiten, Vrienden,
/// een workout opnemen en Profiel. De workflow `.github/workflows/demo-video.yml` neemt het
/// scherm van de simulator op terwijl deze test draait.
///
/// De app praat met een echte, lokaal gestarte Metric-server met de demo-gegevens uit
/// `web/scripts/seed.ts`. Het startargument `-UITestDemo` laat de app leeg beginnen en slaat
/// Gezondheid over (zie `Shared/DemoMode.swift`).
final class DemoWalkthroughUITests: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var started = Date()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestDemo", "YES", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["TZ"] = "Europe/Amsterdam"
    }

    override func tearDownWithError() throws {
        if let run = testRun, run.failureCount + run.unexpectedExceptionCount > 0 {
            dumpState("mislukt")
        }
    }

    func testWalkthrough() throws {
        started = Date()
        // Zet de simulator alvast bij de ingang van het Vondelpark, waar het pad van de opname begint.
        XCUIDevice.shared.location = XCUILocation(
            location: CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 52.3611, longitude: 4.8805),
                altitude: 1,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: Date()
            )
        )
        app.launch()
        mark("gestart")

        try logIn()
        try showToday()
        try showActivities()
        try showFriends()
        try recordWorkout()
        try showProfile()

        // Slotbeeld: de week met de nieuwe workout erbij.
        tapTab("Vandaag")
        drag(from: 0.35, to: 0.85, velocity: 1500)
        drag(from: 0.35, to: 0.85, velocity: 1500)
        pause(2.5)
        mark("klaar")
    }

    // MARK: Stappen

    private func logIn() throws {
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 90), "Het inlogscherm verschijnt niet")
        mark("inlogscherm")
        pause(1.5)

        email.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        // Een verse simulator legt bij het eerste toetsenbord het veegtypen uit.
        tapIfPresent(["Ga door", "Continue", "Doorgaan"], in: [app])
        app.typeText("sanne@metric.test")

        app.secureTextFields["auth-password"].tap()
        // De return-toets sluit het toetsenbord, zodat de knop zichtbaar is.
        app.typeText("metric-demo\n")
        pause(0.5)

        let submit = app.buttons["auth-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5), "De knop 'Log in' ontbreekt")
        submit.tap()
        mark("ingelogd")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "Na het inloggen verschijnt de tabbalk niet")
    }

    private func showToday() throws {
        XCTAssertTrue(app.staticTexts["Deze week"].waitForExistence(timeout: 20), "De kaart 'Deze week' ontbreekt")
        // Wacht tot de eerste synchronisatie de activiteiten heeft binnengehaald.
        _ = app.staticTexts["Recent"].waitForExistence(timeout: 10)
        mark("vandaag")
        pause(2.5)
        scrollDown()
        pause(1.5)
        scrollDown()
        pause(1.5)
    }

    private func showActivities() throws {
        tapTab("Activiteiten")
        mark("activiteiten")
        let anyRow = element(idPrefix: "activity-row-")
        XCTAssertTrue(anyRow.waitForExistence(timeout: 30), "De lijst met activiteiten blijft leeg")
        pause(1.5)

        // Open een hardloopactiviteit met een route; zoek zo nodig iets verder in de lijst.
        let routeRow = element(idPrefix: "activity-row-run-route")
        for _ in 0..<3 where !(routeRow.exists && routeRow.isHittable) {
            scrollDown(0.3)
            pause(0.6)
        }
        if routeRow.exists {
            routeRow.tap()
        } else {
            anyRow.tap()
        }
        mark("activiteit")
        // De route komt van de server; daarna verschijnt de kaart.
        pause(2.5)
        // Veeg op de cijfers en onder de kaart, niet op de kaart zelf: die zou meeschuiven.
        drag(from: 0.55, to: 0.22)
        pause(2.5)
        drag(from: 0.82, to: 0.45)
        pause(1.5)
        goBack()
        pause(0.5)
    }

    private func showFriends() throws {
        tapTab("Vrienden")
        mark("vrienden")

        // Kudos voor de eerste activiteit van een vriend die er nog geen heeft.
        let kudos = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'feed-kudos-' AND identifier != 'feed-kudos-sanne' AND label == 'Geef kudos'")
        ).firstMatch
        let anyKudos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'feed-kudos-'")).firstMatch
        XCTAssertTrue(anyKudos.waitForExistence(timeout: 30), "De feed blijft leeg")
        pause(1.5)
        var found = kudos.exists && kudos.isHittable
        for _ in 0..<5 where !found {
            scrollDown(0.4)
            found = kudos.exists && kudos.isHittable
        }
        if found {
            kudos.tap()
            mark("kudos")
        }
        pause(2)

        let segments = app.segmentedControls
        segments.buttons["Ranglijst"].firstMatch.tap()
        mark("ranglijst")
        pause(2.2)
        let distance = segments.buttons["Afstand"].firstMatch
        if distance.waitForExistence(timeout: 3) {
            distance.tap()
            pause(1.5)
        }

        segments.buttons["Vrienden"].firstMatch.tap()
        mark("vriendenlijst")
        // Wacht op de lijst van de server: het verzoek van Emma en de vrienden.
        _ = app.staticTexts["Emma Smit"].waitForExistence(timeout: 10)
        pause(2)
    }

    private func recordWorkout() throws {
        tapTab("Opnemen")
        mark("opnemen")
        let run = app.buttons["sport-run"]
        XCTAssertTrue(run.waitForExistence(timeout: 15), "De sportkiezer ontbreekt")
        pause(1.2)
        app.buttons["sport-ride"].tap()
        pause(0.7)
        run.tap()
        pause(0.8)

        app.buttons["record-start"].tap()
        mark("aftellen")

        // 3-2-1, daarna loopt de opname.
        let stop = app.buttons["record-stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 20), "De opname start niet")
        mark("opname")
        // Is de locatietoegang niet vooraf verleend, dan vraagt iOS er nu om.
        if springboard.alerts.firstMatch.exists {
            tapIfPresent(["Allow While Using App", "Sta toe bij gebruik van app", "Bij gebruik van app"], in: [springboard])
        }
        // Hardlopen: de workflow laat de simulator nu een pad door het Vondelpark aflopen
        // (`simctl location start`), gestart door dit signaalbestand. Zonder workflow staat de loper stil.
        if let directory = ProcessInfo.processInfo.environment["DEMO_SIGNAL_DIR"] {
            FileManager.default.createFile(atPath: directory + "/location-scenario", contents: Data())
        }
        pause(16)

        stop.tap()
        let save = app.buttons["Bewaar workout"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "De vraag 'Workout beëindigen?' verschijnt niet")
        pause(0.8)
        save.tap()
        mark("finish")

        // Het finish-scherm: de cijfers tellen op en de baan van de week loopt vol.
        pause(3)
        let done = app.buttons["finish-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "Het finish-scherm verschijnt niet")
        pause(2)
        done.tap()
        pause(1)
    }

    private func showProfile() throws {
        tapTab("Profiel")
        mark("profiel")
        pause(2)
        scrollDown()
        pause(1.5)
    }

    // MARK: Hulpjes

    private func tapTab(_ title: String) {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Tabblad '\(title)' ontbreekt")
        button.tap()
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) {
            back.tap()
        }
    }

    private func element(idPrefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", idPrefix))
            .firstMatch
    }

    /// Rustig omhoog vegen, zodat de beweging in de video te volgen is.
    private func scrollDown(_ fraction: CGFloat = 0.42) {
        drag(from: 0.72, to: 0.72 - fraction)
    }

    /// Sleept verticaal over het midden van het scherm; `from` en `to` zijn fracties van de hoogte.
    private func drag(from: CGFloat, to: CGFloat, velocity: CGFloat = 500) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
        start.press(
            forDuration: 0.05,
            thenDragTo: end,
            withVelocity: XCUIGestureVelocity(rawValue: velocity),
            thenHoldForDuration: 0.15
        )
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Tikt de eerste knop met een van deze labels aan, als die er is (bv. in een systeemvenster).
    @discardableResult
    private func tapIfPresent(_ labels: [String], in apps: [XCUIApplication]) -> Bool {
        for candidate in apps {
            for label in labels {
                let button = candidate.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
        }
        return false
    }

    /// Tijdstempel in het testlog, om de video achteraf te kunnen knippen.
    private func mark(_ name: String) {
        let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
        print("DEMO-MARK \(name) t=\(seconds) epoch=\(Date().timeIntervalSince1970)")
    }

    /// Bij een fout: schermafbeelding als bijlage en de toegankelijkheidsboom in het log.
    private func dumpState(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "demo-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("DEMO-HIERARCHY-BEGIN")
        print(app.debugDescription)
        print("DEMO-HIERARCHY-END")
    }
}
