import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            if app.isRestoring {
                ProgressView()
            } else if app.me == nil {
                AuthView()
            } else {
                MainTabView()
            }
        }
        .task {
            await app.restoreSession()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder = WorkoutRecorder()
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("Vandaag", systemImage: "chart.bar.fill") }
            .tag(0)

            NavigationStack {
                ActivitiesView()
            }
            .tabItem { Label("Activiteiten", systemImage: "list.bullet") }
            .tag(1)

            NavigationStack {
                RecordView()
            }
            .tabItem { Label("Opnemen", systemImage: "record.circle") }
            .tag(2)

            NavigationStack {
                FriendsView()
            }
            .tabItem { Label("Vrienden", systemImage: "person.2.fill") }
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profiel", systemImage: "person.crop.circle") }
            .tag(4)
        }
        .environmentObject(recorder)
        .task {
            await app.refreshAll()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await app.refreshAll()
                }
            }
        }
    }
}
