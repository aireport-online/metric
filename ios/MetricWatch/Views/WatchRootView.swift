import SwiftUI
import MetricCore

struct WatchRootView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        if workout.activeType != nil {
            SessionView()
        } else if let summary = workout.summary {
            SummaryView(summary: summary)
        } else {
            NavigationStack {
                HomeView()
            }
        }
    }
}

/// Startscherm: weekdoel-ring en de knop om een workout te starten.
struct HomeView: View {
    @EnvironmentObject private var workout: WorkoutManager
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let context = connectivity.context, context.isLoggedIn {
                    ZStack {
                        ProgressRing(progress: context.progress, lineWidth: 10)
                        VStack(spacing: 0) {
                            Text("\(context.weekMinutes)")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .monospacedDigit()
                            Text("van \(context.goalMinutes) min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .padding(.top, 4)

                    if context.streakWeeks > 0 {
                        Label(
                            context.streakWeeks == 1 ? "1 week op rij" : "\(context.streakWeeks) weken op rij",
                            systemImage: "flame.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                    }
                } else {
                    Text("Open Metric op je iPhone en log in om je weekdoel hier te zien.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                NavigationLink {
                    SportPickerView()
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let errorMessage = workout.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Metric")
        .onAppear {
            workout.requestAuthorization()
        }
    }
}

struct SportPickerView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        List(ActivityType.allCases) { type in
            Button {
                workout.start(type)
            } label: {
                Label(type.displayName, systemImage: type.symbolName)
            }
        }
        .navigationTitle("Sport")
    }
}

/// Lopende workout: live-gegevens en bediening als twee pagina's.
struct SessionView: View {
    private enum Page {
        case controls, metrics
    }

    @EnvironmentObject private var workout: WorkoutManager
    @State private var page: Page = .metrics

    var body: some View {
        if workout.isEnding {
            VStack(spacing: 8) {
                ProgressView()
                Text("Workout opslaan…")
                    .font(.footnote)
            }
        } else {
            TabView(selection: $page) {
                ControlsView()
                    .tag(Page.controls)
                MetricsView()
                    .tag(Page.metrics)
            }
        }
    }
}

struct MetricsView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.duration(workout.builder?.elapsedTime ?? 0))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(workout.isRunning ? Color.yellow : Color.secondary)

                if let type = workout.activeType, type.isDistanceBased {
                    Text(Format.distance(workout.distance))
                        .font(.system(.title3, design: .rounded))
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Text(workout.heartRate > 0 ? "\(Int(workout.heartRate.rounded()))" : "–")
                        .font(.system(.title3, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "heart.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hartslag")
                .accessibilityValue(workout.heartRate > 0 ? "\(Int(workout.heartRate.rounded())) slagen per minuut" : "onbekend")

                Text("\(Int(workout.activeEnergy.rounded())) kcal")
                    .font(.system(.title3, design: .rounded))
                    .monospacedDigit()

                if !workout.isRunning {
                    Text("Gepauzeerd")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .navigationTitle(workout.activeType?.displayName ?? "Workout")
    }
}

struct ControlsView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Button {
                    workout.end()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                }
                .tint(.red)
                Text("Stop")
                    .font(.footnote)
            }
            VStack(spacing: 4) {
                Button {
                    workout.togglePause()
                } label: {
                    Image(systemName: workout.isRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .tint(.yellow)
                Text(workout.isRunning ? "Pauze" : "Hervat")
                    .font(.footnote)
            }
        }
    }
}

struct SummaryView: View {
    @EnvironmentObject private var workout: WorkoutManager

    let summary: WatchWorkoutPayload

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Label(summary.type.displayName, systemImage: summary.type.symbolName)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                SummaryRow(title: "Tijd", value: Format.duration(summary.durationSeconds))
                if let distance = summary.distanceMeters {
                    SummaryRow(title: "Afstand", value: Format.distance(distance))
                }
                if let energy = summary.activeEnergyKcal {
                    SummaryRow(title: "Energie", value: "\(Int(energy.rounded())) kcal")
                }
                if let heartRate = summary.avgHeartRate {
                    SummaryRow(title: "Gem. hartslag", value: "\(Int(heartRate.rounded())) bpm")
                }

                Text("Je workout verschijnt vanzelf in Metric op je iPhone.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Button("Klaar") {
                    workout.summary = nil
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
