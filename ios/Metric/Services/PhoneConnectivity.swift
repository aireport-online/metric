import Foundation
import WatchConnectivity
import MetricCore

/// De iPhone-kant van WatchConnectivity: ontvangt afgeronde workouts van de Watch
/// en stuurt de weekvoortgang terug.
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivity()

    /// Wordt op de main thread aangeroepen voor elke workout die van de Watch binnenkomt.
    var onWorkout: ((WatchWorkoutPayload) -> Void)?

    private var pendingContext: WatchContextPayload?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Stuurt de laatste weekvoortgang naar de Watch (alleen de nieuwste stand wordt bewaard).
    func send(context: WatchContextPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingContext = context
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(context.applicationContext())
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if activationState == .activated, let context = self.pendingContext {
                self.pendingContext = nil
                self.send(context: context)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Nodig bij het wisselen tussen meerdere Watches.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let payload = WatchWorkoutPayload(userInfo: userInfo) else { return }
        DispatchQueue.main.async {
            self.onWorkout?(payload)
        }
    }
}
