import SwiftUI
import WatchKit
import MetricCore

struct WatchRootView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        Group {
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
        .font(.metricText(15))
        .foregroundStyle(Theme.text)
        .tint(Theme.tartan)
    }
}

/// Startscherm: de week als baan en de knop om een workout te starten.
struct HomeView: View {
    @EnvironmentObject private var workout: WorkoutManager
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let context = connectivity.context, context.isLoggedIn {
                    TrackProgressView(
                        lanes: [TrackLane(progress: context.progress)],
                        laneWidth: 9,
                        aspect: 1.6,
                        goalReached: context.goalMinutes > 0 && context.weekMinutes >= context.goalMinutes
                    ) {
                        VStack(spacing: -2) {
                            CountUp(value: Double(context.weekMinutes))
                                .font(.metricNumber(44))
                            Text("van \(context.goalMinutes) min")
                                .font(.metricLabel(12))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Weekdoel")
                    .accessibilityValue("\(context.weekMinutes) van \(context.goalMinutes) minuten")

                    if context.streakWeeks > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(context.streakWeeks)")
                                .font(.metricNumber(22))
                                .foregroundStyle(Theme.volt)
                            Text(context.streakWeeks == 1 ? "week op rij" : "weken op rij")
                                .font(.metricLabel(14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } else {
                    Text("Open Metric op je iPhone en log in om je week hier te zien.")
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                NavigationLink {
                    SportPickerView()
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))

                if let errorMessage = workout.errorMessage {
                    Text(errorMessage)
                        .font(.metricText(12))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Theme.bg)
        .navigationTitle("Metric")
        .onAppear {
            workout.requestAuthorization()
        }
    }
}

/// Sport kiezen; daarna telt het startschot af: 3, 2, 1.
struct SportPickerView: View {
    @EnvironmentObject private var workout: WorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        List(ActivityType.allCases) { type in
            Button {
                begin(type)
            } label: {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(type.tint)
                        .frame(width: 3, height: 18)
                    Image(systemName: type.symbolName)
                        .foregroundStyle(type.tint)
                        .frame(width: 26)
                    Text(type.displayName)
                        .font(.metricText(15, weight: .medium))
                        .foregroundStyle(Theme.text)
                }
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.surface)
            )
        }
        .navigationTitle("Sport")
        .overlay {
            if let countdown {
                ZStack {
                    Theme.bg.ignoresSafeArea()
                    VStack(spacing: 0) {
                        CountdownNumber(number: countdown, size: 110)
                        Text("Tik om te annuleren")
                            .font(.metricText(12))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    cancel()
                }
                .transition(AnyTransition.opacity)
            }
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    private func begin(_ type: ActivityType) {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for number in [3, 2, 1] {
                withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.kick) {
                    countdown = number
                }
                WKInterfaceDevice.current().play(.click)
                try? await Task.sleep(nanoseconds: 700_000_000)
                if Task.isCancelled {
                    return
                }
            }
            WKInterfaceDevice.current().play(.start)
            countdown = nil
            workout.start(type)
        }
    }

    private func cancel() {
        countdownTask?.cancel()
        countdownTask = nil
        withAnimation(Theme.Motion.quick) {
            countdown = nil
        }
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
                    .font(.metricText(13))
                    .foregroundStyle(Theme.textSecondary)
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    LiveDot(isLive: workout.isRunning)
                    Text(workout.isRunning ? "Live" : "Gepauzeerd")
                        .font(.metricLabel(13))
                        .foregroundStyle(workout.isRunning ? Theme.volt : Theme.textMuted)
                    Spacer()
                    if let type = workout.activeType {
                        Image(systemName: type.symbolName)
                            .font(.footnote)
                            .foregroundStyle(type.tint)
                            .accessibilityLabel(type.displayName)
                    }
                }

                Text(Format.duration(workout.builder?.elapsedTime ?? 0))
                    .font(.metricNumber(44))
                    .monospacedDigit()
                    .foregroundStyle(workout.isRunning ? Theme.text : Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Tijd")

                if let type = workout.activeType, type.isDistanceBased {
                    let distance = splitFigure(Format.distance(workout.distance))
                    FigureText(value: distance.value, unit: distance.unit, size: 26)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    FigureText(
                        value: workout.heartRate > 0 ? "\(Int(workout.heartRate.rounded()))" : "–",
                        unit: "bpm",
                        size: 26
                    )
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.tartan)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hartslag")
                .accessibilityValue(workout.heartRate > 0 ? "\(Int(workout.heartRate.rounded())) slagen per minuut" : "onbekend")

                FigureText(value: "\(Int(workout.activeEnergy.rounded()))", unit: "kcal", size: 26)
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
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                Button {
                    workout.end()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.danger)
                        .frame(width: 62, height: 62)
                        .background(Theme.surfaceRaised, in: Circle())
                        .overlay(Circle().stroke(Theme.lineStrong, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Stop")
                Text("Stop")
                    .font(.metricText(12))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 4) {
                Button {
                    workout.togglePause()
                } label: {
                    Image(systemName: workout.isRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 62, height: 62)
                        .background(Theme.tartan, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(workout.isRunning ? "Pauzeer" : "Hervat")
                Text(workout.isRunning ? "Pauze" : "Hervat")
                    .font(.metricText(12))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Het finish-moment: de cijfers tellen op, met een tik op de pols.
struct SummaryView: View {
    @EnvironmentObject private var workout: WorkoutManager

    let summary: WatchWorkoutPayload

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Label("Finish", systemImage: "flag.checkered")
                    .font(.metricText(12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Theme.volt, in: Capsule())

                HStack(spacing: 6) {
                    Image(systemName: summary.type.symbolName)
                        .foregroundStyle(summary.type.tint)
                        .accessibilityHidden(true)
                    Text(summary.type.displayName)
                        .font(.metricLabel(15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .entrance(0)

                VStack(alignment: .leading, spacing: 0) {
                    CountUp(value: summary.durationSeconds, format: { Format.duration($0) })
                        .font(.metricNumber(44))
                    Text("tijd")
                        .font(.metricLabel(12))
                        .foregroundStyle(Theme.textMuted)
                }
                .accessibilityElement(children: .combine)
                .entrance(1)

                if let distance = summary.distanceMeters {
                    let parts = splitFigure(Format.distance(distance))
                    SummaryRow(title: "afstand", value: parts.value, unit: parts.unit)
                        .entrance(2)
                }
                if let energy = summary.activeEnergyKcal {
                    SummaryRow(title: "energie", value: "\(Int(energy.rounded()))", unit: "kcal")
                        .entrance(3)
                }
                if let heartRate = summary.avgHeartRate {
                    SummaryRow(title: "gem. hartslag", value: "\(Int(heartRate.rounded()))", unit: "bpm")
                        .entrance(4)
                }

                Text("Je workout verschijnt vanzelf in Metric op je iPhone.")
                    .font(.metricText(12))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)

                Button("Klaar") {
                    workout.summary = nil
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .background(Theme.bg)
        .onAppear {
            WKInterfaceDevice.current().play(.success)
        }
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FigureText(value: value, unit: unit, size: 26)
            Text(title)
                .font(.metricLabel(12))
                .foregroundStyle(Theme.textMuted)
        }
        .accessibilityElement(children: .combine)
    }
}
