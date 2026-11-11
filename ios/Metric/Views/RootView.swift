import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if app.isRestoring {
                LaunchView()
                    .transition(.opacity)
            } else if app.me == nil {
                AuthView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.base, value: app.isRestoring)
        .animation(Theme.Motion.base, value: app.me == nil)
        .task {
            await app.restoreSession()
        }
    }
}

/// Het beeldmerk boven een baan die een ronde loopt terwijl de sessie wordt hersteld.
private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("LogoMark")
                .accessibilityHidden(true)
            TrackProgressView(lanes: [TrackLane(progress: 1)], laneWidth: 6, aspect: 2.6)
                .frame(width: 96)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Metric wordt geladen")
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
            .tabItem { Label("Vandaag", systemImage: "flag.checkered") }
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
        .sensoryFeedback(.selection, trigger: selection)
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
