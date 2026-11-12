import SwiftUI
import SwiftData
import MetricCore

struct RecordView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var recorder: WorkoutRecorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedType: ActivityType = .run
    @State private var confirmStop = false
    @State private var isSaving = false
    @State private var saved: ActivityRecord?
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var startShots = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if recorder.isActive {
                recordingView
                    .transition(AnyTransition.opacity)
            } else {
                pickerView
                    .transition(AnyTransition.opacity)
            }
        }
        .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.slow, value: recorder.isActive)
        .overlay {
            if let countdown {
                countdownOverlay(countdown)
                    .transition(AnyTransition.opacity)
            }
        }
        .navigationTitle(recorder.isActive ? recorder.type.displayName : "Opnemen")
        .navigationBarTitleDisplayMode(recorder.isActive ? .inline : .large)
        .sensoryFeedback(.impact(weight: .light), trigger: countdown)
        .sensoryFeedback(.impact(weight: .heavy), trigger: startShots)
        .onChange(of: startShots) { _, _ in
            SoundPlayer.shared.play(.start)
        }
        // Hangt aan het scherm zelf en niet aan de opnameweergave: die verdwijnt zodra de workout stopt.
        .confirmationDialog("Workout beëindigen?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Bewaar workout") {
                finish()
            }
            Button("Gooi weg", role: .destructive) {
                recorder.discard()
            }
            Button("Ga door", role: .cancel) {}
        }
        .sheet(item: $saved) { record in
            FinishSummaryView(record: record) {
                saved = nil
            }
        }
    }

    // MARK: Sport kiezen

    private var pickerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Kies je sport")
                    .font(.metricHeading(24))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(ActivityType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            SportTile(type: type, isSelected: selectedType == type)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityAddTraits(selectedType == type ? .isSelected : [])
                        .accessibilityIdentifier("sport-\(type.rawValue)")
                    }
                }
                .animation(reduceMotion ? nil : Theme.Motion.kick, value: selectedType)
                .sensoryFeedback(.selection, trigger: selectedType)

                Text(selectedType.usesGPS
                     ? "Je route en afstand worden met GPS vastgelegd. Houd je iPhone bij je."
                     : "Voor deze sport wordt alleen de tijd bijgehouden. Draag je Watch voor hartslag en energie.")
                    .font(.metricText(14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    beginCountdown()
                } label: {
                    Label("Start \(selectedType.displayName.lowercased())", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || countdown != nil)
                .accessibilityIdentifier("record-start")

                if isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Workout wordt opgeslagen…")
                            .font(.metricText(14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: Startschot

    private func countdownOverlay(_ number: Int) -> some View {
        ZStack {
            Theme.bg.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    SportStripe(type: selectedType)
                    Text(selectedType.displayName)
                        .font(.metricLabel(20))
                        .foregroundStyle(Theme.textSecondary)
                }
                CountdownNumber(number: number)
                    .frame(height: 220)
                Button("Annuleer") {
                    cancelCountdown()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func beginCountdown() {
        countdownTask?.cancel()
        let type = selectedType
        countdownTask = Task { @MainActor in
            for number in [3, 2, 1] {
                withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.kick) {
                    countdown = number
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                if Task.isCancelled {
                    return
                }
            }
            withAnimation(Theme.Motion.quick) {
                countdown = nil
            }
            startShots += 1
            recorder.start(type)
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        withAnimation(Theme.Motion.quick) {
            countdown = nil
        }
    }

    // MARK: Opname

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    LiveDot(isLive: recorder.state == .recording)
                    Text(recorder.state == .paused ? "Gepauzeerd" : "Live")
                        .font(.metricLabel(18))
                        .foregroundStyle(recorder.state == .paused ? Theme.textMuted : Theme.volt)
                }
                Text(Format.duration(recorder.elapsed))
                    .font(.metricNumber(96))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel("Tijd")
                    .accessibilityValue(Format.duration(recorder.elapsed))
            }
            .padding(.horizontal, 16)

            if recorder.type.usesGPS {
                HStack(alignment: .top, spacing: 16) {
                    let distance = splitFigure(Format.distance(recorder.distanceMeters))
                    StatTile(title: "Afstand", value: distance.value, unit: distance.unit, size: 44)
                    let pace = splitFigure(
                        Format.paceOrSpeed(
                            type: recorder.type,
                            distanceMeters: recorder.distanceMeters,
                            durationSeconds: recorder.elapsed
                        ) ?? "–"
                    )
                    StatTile(
                        title: recorder.type.prefersSpeed ? "Snelheid" : "Tempo",
                        value: pace.value,
                        unit: pace.unit,
                        size: 44
                    )
                }
                .metricCard()
                .padding(.horizontal, 16)

                if recorder.locationDenied {
                    Label("Geen toegang tot je locatie. Zet die aan bij Instellingen om je route vast te leggen.", systemImage: "location.slash")
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 16)
                } else if !recorder.hasGPSFix {
                    Label("GPS-signaal zoeken…", systemImage: "location")
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 40) {
                Button {
                    confirmStop = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundStyle(Theme.danger)
                        .frame(width: 76, height: 76)
                        .background(Theme.surfaceRaised, in: Circle())
                        .overlay(Circle().stroke(Theme.lineStrong, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Stop")
                .accessibilityIdentifier("record-stop")

                Button {
                    if recorder.state == .paused {
                        recorder.resume()
                    } else {
                        recorder.pause()
                    }
                } label: {
                    Image(systemName: recorder.state == .paused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 76, height: 76)
                        .background(Theme.tartan, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(recorder.state == .paused ? "Hervat" : "Pauzeer")
            }
            .padding(.bottom, 32)
            .sensoryFeedback(.impact(weight: .medium), trigger: recorder.state == .paused)
        }
    }

    private func finish() {
        guard let workout = recorder.finish() else { return }
        isSaving = true
        Task {
            let record = await app.saveRecording(workout)
            isSaving = false
            saved = record
        }
    }
}

/// Tegel in de sportkiezer: de gekozen sport is een tartan vlak met inkt-tekst.
private struct SportTile: View {
    let type: ActivityType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: type.symbolName)
                .font(.title2)
                .foregroundStyle(isSelected ? Theme.ink : type.tint)
            Text(type.displayName)
                .font(.metricText(12, weight: .medium))
                .foregroundStyle(isSelected ? Theme.ink : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            isSelected ? Theme.tartan : Theme.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        )
        .scaleEffect(isSelected ? 1.04 : 1)
    }
}

/// Het finish-moment na een opname: de cijfers tellen op en de baan van deze week loopt vol.
struct FinishSummaryView: View {
    @EnvironmentObject private var app: AppModel
    @Query(sort: \ActivityRecord.startedAt, order: .reverse) private var allRecords: [ActivityRecord]

    let record: ActivityRecord
    let onDone: () -> Void

    @State private var finishes = 0

    var body: some View {
        let samples = allRecords.filter { !$0.isPendingDelete }.map { $0.sample }
        let weekSeconds = StatsCalculator.weekly(samples, weeks: 1).last?.durationSeconds ?? 0
        let weekMinutes = Int((weekSeconds / 60).rounded())
        let goalMinutes = app.me?.weeklyGoalMinutes ?? 150
        let goalReached = goalMinutes > 0 && weekMinutes >= goalMinutes

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Finish", systemImage: "flag.checkered")
                            .font(.metricText(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(Theme.volt, in: Capsule())
                        Text(record.title.isEmpty ? record.type.displayName : record.title)
                            .font(.metricHeading(34))
                        ActivityHeroFigure(
                            type: record.type,
                            durationSeconds: record.durationSeconds,
                            distanceMeters: record.distanceMeters,
                            size: 88
                        )
                    }
                    .entrance(0)

                    ActivityStatsGrid(
                        type: record.type,
                        durationSeconds: record.durationSeconds,
                        distanceMeters: record.distanceMeters,
                        elevationGainMeters: record.elevationGainMeters,
                        activeEnergyKcal: record.activeEnergyKcal,
                        avgHeartRate: record.avgHeartRate,
                        maxHeartRate: record.maxHeartRate
                    )
                    .metricCard()
                    .entrance(1)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Je week")
                            .font(.metricHeading(24))
                        TrackProgressView(
                            lanes: [TrackLane(progress: goalMinutes > 0 ? Double(weekMinutes) / Double(goalMinutes) : 0)],
                            goalReached: goalReached
                        ) {
                            VStack(spacing: -2) {
                                CountUp(value: Double(weekMinutes))
                                    .font(.metricNumber(56))
                                Text("van \(goalMinutes) min")
                                    .font(.metricLabel(15))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Weekdoel")
                        .accessibilityValue("\(weekMinutes) van \(goalMinutes) minuten")
                        Text(goalReached ? "Weekdoel gehaald." : "Nog \(max(goalMinutes - weekMinutes, 0)) min tot je weekdoel.")
                            .font(.metricText(15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .metricCard()
                    .entrance(2)

                    VStack(spacing: 10) {
                        Button("Klaar") {
                            onDone()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("finish-done")

                        NavigationLink {
                            ActivityDetailView(record: record)
                        } label: {
                            Text("Bekijk activiteit")
                        }
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true, compact: false))
                    }
                    .entrance(3)
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
        }
        .font(.metricText())
        .foregroundStyle(Theme.text)
        .tint(Theme.tartan)
        .sensoryFeedback(.success, trigger: finishes)
        .onAppear {
            finishes += 1
            SoundPlayer.shared.play(.finish)
        }
    }
}
