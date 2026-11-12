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
        if DemoMode.isActive {
            MetricApp.resetForDemo(container)
        }
        self.container = container
        _app = StateObject(wrappedValue: AppModel(container: container))
        Appearance.apply()
    }

    /// Demo-modus (`-UITestDemo`): begin elke keer leeg op het inlogscherm.
    @MainActor
    private static func resetForDemo(_ container: ModelContainer) {
        KeychainStore.deleteToken()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        let context = container.mainContext
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>())) ?? []
        for record in records {
            context.delete(record)
        }
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(app.sync)
                .font(.metricText())
                .foregroundStyle(Theme.text)
                .tint(Theme.tartan)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
