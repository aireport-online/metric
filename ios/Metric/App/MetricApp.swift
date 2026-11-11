import SwiftUI
import SwiftData

@main
struct MetricApp: App {
    private let container: ModelContainer
    @StateObject private var app: AppModel

    @MainActor
    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: ActivityRecord.self)
        } catch {
            fatalError("De lokale opslag kon niet worden geopend: \(error)")
        }
        self.container = container
        _app = StateObject(wrappedValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(app.sync)
        }
        .modelContainer(container)
    }
}
