import XCTest

/// Loopt de Watch-app door voor de demovideo: startscherm met de week, sport kiezen, aftellen,
/// een lopende workout, pauze en hervatten, stoppen en de samenvatting.
///
/// Met `-UITestDemo` gebruikt de app geen HealthKit: de workout loopt op een timer met
/// voorbeeldwaarden en het startscherm toont een voorbeeldweek (zie `Shared/DemoMode.swift`).
final class WatchDemoUITests: XCTestCase {
    private var app: XCUIApplication!
    private var started = Date()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestDemo", "YES", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
    }

    override func tearDownWithError() throws {
        if let run = testRun, run.failureCount + run.unexpectedExceptionCount > 0 {
            print("DEMO-HIERARCHY-BEGIN")
            print(app.debugDescription)
            print("DEMO-HIERARCHY-END")
        }
    }

    func testWalkthrough() throws {
        started = Date()
        app.launch()
        mark("gestart")

        // Startscherm: de baan van de week loopt vol.
        let start = app.buttons["watch-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 120), "Het startscherm verschijnt niet")
        mark("startscherm")
        pause(3.5)
        start.tap()

        // Sport kiezen, daarna telt het startschot af.
        let run = app.buttons["watch-sport-run"]
        XCTAssertTrue(run.waitForExistence(timeout: 20), "De sportlijst verschijnt niet")
        mark("sport")
        pause(2)
        run.tap()
        mark("aftellen")

        // Lopende workout.
        let liveState = app.staticTexts["watch-live-state"]
        XCTAssertTrue(liveState.waitForExistence(timeout: 20), "De workout start niet")
        mark("live")
        pause(12)

        // Naar de bediening: pauzeren en hervatten.
        let toggle = app.buttons["watch-pause-toggle"]
        showControls(toggle)
        mark("bediening")
        pause(1.2)
        toggle.tap()
        mark("pauze")
        pause(2.5)
        toggle.tap()
        mark("hervat")
        pause(1.2)
        app.swipeLeft()
        pause(4)

        // Stoppen en de samenvatting.
        let stop = app.buttons["watch-stop"]
        showControls(stop)
        pause(1)
        stop.tap()
        mark("stop")

        let done = app.buttons["watch-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 20), "De samenvatting verschijnt niet")
        mark("samenvatting")
        pause(3.5)
        app.swipeUp()
        pause(2.5)
        done.tap()

        XCTAssertTrue(start.waitForExistence(timeout: 20), "Na 'Klaar' komt het startscherm niet terug")
        pause(2.5)
        mark("klaar")
    }

    /// Veegt naar de pagina met de knoppen (links van de live-gegevens).
    private func showControls(_ button: XCUIElement) {
        for _ in 0..<3 where !(button.exists && button.isHittable) {
            app.swipeRight()
            pause(0.8)
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10), "De bediening van de workout verschijnt niet")
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Tijdstempel in het testlog, om de video achteraf te kunnen knippen.
    private func mark(_ name: String) {
        let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
        print("DEMO-MARK \(name) t=\(seconds) epoch=\(Date().timeIntervalSince1970)")
    }
}
