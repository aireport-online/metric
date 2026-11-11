import SwiftUI

@main
struct MetricWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(workoutManager)
                .environmentObject(connectivity)
                .onAppear {
                    connectivity.activate()
                }
        }
    }
}
