import Foundation
import Combine
import CoreLocation
import MetricCore

/// Het resultaat van een opname op de iPhone.
struct RecordedWorkout {
    let clientId: String
    let type: ActivityType
    let start: Date
    let end: Date
    let durationSeconds: Double
    let pauses: [DateInterval]
    let distanceMeters: Double?
    let elevationGainMeters: Double?
    let locations: [CLLocation]
}

/// Neemt een workout op met de iPhone: tijd, en voor buitensporten GPS-afstand en route.
@MainActor
final class WorkoutRecorder: ObservableObject {
    enum Phase {
        case idle, recording, paused
    }

    @Published private(set) var state: Phase = .idle
    @Published private(set) var type: ActivityType = .run
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var locationDenied = false
    @Published private(set) var hasGPSFix = false

    private let manager = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    private var timer: Timer?
    private var startDate: Date?
    private var segmentStart: Date?
    private var accumulated: TimeInterval = 0
    private var pauseStart: Date?
    private var pauses: [DateInterval] = []
    private var locations: [CLLocation] = []
    private var lastLocation: CLLocation?
    private var referenceAltitude: Double?
    private var elevationGain: Double = 0

    init() {
        locationDelegate.onLocations = { [weak self] locations in
            Task { @MainActor in
                self?.handle(locations)
            }
        }
        locationDelegate.onAuthorization = { [weak self] status in
            Task { @MainActor in
                self?.handleAuthorizationChange(status)
            }
        }
        manager.delegate = locationDelegate
        if DemoMode.isActive {
            // Demo-modus: een eenvoudige sessie op de voorgrond. Met de afstelling hieronder geeft
            // de simulator na de eerste positie geen gesimuleerde verplaatsing meer door.
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        } else {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.activityType = .fitness
            manager.distanceFilter = 5
            manager.pausesLocationUpdatesAutomatically = false
        }
    }

    var isActive: Bool {
        state != .idle
    }

    func start(_ type: ActivityType) {
        guard state == .idle else { return }
        self.type = type
        let now = Date()
        startDate = now
        segmentStart = now
        accumulated = 0
        elapsed = 0
        distanceMeters = 0
        pauses = []
        pauseStart = nil
        locations = []
        lastLocation = nil
        referenceAltitude = nil
        elevationGain = 0
        hasGPSFix = false
        state = .recording
        startTimer()
        if type.usesGPS {
            startLocationUpdates()
        }
    }

    func pause() {
        guard state == .recording else { return }
        let now = Date()
        if let segmentStart {
            accumulated += now.timeIntervalSince(segmentStart)
        }
        segmentStart = nil
        pauseStart = now
        lastLocation = nil
        elapsed = accumulated
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        let now = Date()
        if let pauseStart {
            pauses.append(DateInterval(start: pauseStart, end: now))
        }
        pauseStart = nil
        segmentStart = now
        state = .recording
    }

    /// Stopt de opname en geeft het resultaat terug (of `nil` als er niets liep).
    func finish() -> RecordedWorkout? {
        guard state != .idle, let startDate else { return nil }
        let now = Date()
        if state == .recording, let segmentStart {
            accumulated += now.timeIntervalSince(segmentStart)
        }
        // Eindigt de workout in een pauze, dan is het begin van die pauze het einde van de workout.
        let end = pauseStart ?? now
        let result = RecordedWorkout(
            clientId: ClientID.new(),
            type: type,
            start: startDate,
            end: end,
            durationSeconds: accumulated,
            pauses: pauses,
            distanceMeters: type.usesGPS && distanceMeters > 0 ? distanceMeters : nil,
            elevationGainMeters: type.usesGPS && elevationGain > 0 ? elevationGain : nil,
            locations: locations
        )
        reset()
        return result
    }

    func discard() {
        reset()
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        state = .idle
        startDate = nil
        segmentStart = nil
        pauseStart = nil
        accumulated = 0
        elapsed = 0
        distanceMeters = 0
        pauses = []
        locations = []
        lastLocation = nil
        hasGPSFix = false
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard state == .recording, let segmentStart else { return }
        elapsed = accumulated + Date().timeIntervalSince(segmentStart)
    }

    private func startLocationUpdates() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
            return
        default:
            break
        }
        locationDenied = false
        beginUpdates()
    }

    private func beginUpdates() {
        // Blijft de route volgen als het scherm uit gaat (vereist de achtergrondmodus `location`).
        // In de demo-modus blijft de app op de voorgrond en is dat niet nodig.
        if !DemoMode.isActive {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
    }

    private func handle(_ newLocations: [CLLocation]) {
        guard state != .idle else { return }
        for location in newLocations {
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 50 else { continue }
            hasGPSFix = true
            guard state == .recording else { continue }
            if let lastLocation {
                distanceMeters += location.distance(from: lastLocation)
            }
            lastLocation = location
            locations.append(location)
            trackElevation(location)
        }
    }

    /// Telt stijging pas mee na 3 meter verschil, zodat GPS-ruis niet optelt.
    private func trackElevation(_ location: CLLocation) {
        guard location.verticalAccuracy > 0 else { return }
        guard let reference = referenceAltitude else {
            referenceAltitude = location.altitude
            return
        }
        let delta = location.altitude - reference
        if delta >= 3 {
            elevationGain += delta
            referenceAltitude = location.altitude
        } else if delta <= -3 {
            referenceAltitude = location.altitude
        }
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            locationDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            locationDenied = false
            if state != .idle, type.usesGPS {
                beginUpdates()
            }
        default:
            break
        }
    }
}

/// CoreLocation-delegate; geeft de callbacks door aan de recorder.
private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocations: (([CLLocation]) -> Void)?
    var onAuthorization: ((CLAuthorizationStatus) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onLocations?(locations)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorization?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Tijdelijke fouten (geen fix) negeren we; CoreLocation blijft het proberen.
    }
}
