import Foundation
import Combine
import WatchConnectivity
import MetricCore

/// De Watch-kant van WatchConnectivity: ontvangt de weekvoortgang van de iPhone
/// en stuurt afgeronde workouts terug.
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published private(set) var context: WatchContextPayload?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState != .activated {
            session.activate()
        }
    }

    /// Zet de workout in de wachtrij voor de iPhone; wordt ook afgeleverd als de iPhone-app niet open is.
    func send(workout: WatchWorkoutPayload) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(workout.userInfo())
    }

    private func apply(_ applicationContext: [String: Any]) {
        guard let payload = WatchContextPayload(applicationContext: applicationContext) else { return }
        DispatchQueue.main.async {
            self.context = payload
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }
}
