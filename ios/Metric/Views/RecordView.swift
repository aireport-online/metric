import SwiftUI
import MetricCore

struct RecordView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var recorder: WorkoutRecorder

    @State private var selectedType: ActivityType = .run
    @State private var confirmStop = false
    @State private var isSaving = false
    @State private var saved: ActivityRecord?

    var body: some View {
        Group {
            if recorder.isActive {
                recordingView
            } else {
                pickerView
            }
        }
        .navigationTitle(recorder.isActive ? recorder.type.displayName : "Opnemen")
        .navigationBarTitleDisplayMode(recorder.isActive ? .inline : .large)
        .sheet(item: $saved) { record in
            NavigationStack {
                ActivityDetailView(record: record)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Klaar") {
                                saved = nil
                            }
                        }
                    }
            }
        }
    }

    // MARK: Sport kiezen

    private var pickerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Kies een sport")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(ActivityType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.symbolName)
                                    .font(.title2)
                                Text(type.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .foregroundStyle(selectedType == type ? Color.white : Color.primary)
                            .background(
                                selectedType == type ? Color.accentColor : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedType == type ? .isSelected : [])
                    }
                }

                Text(selectedType.usesGPS
                     ? "Je route en afstand worden met GPS vastgelegd. Houd je iPhone bij je."
                     : "Voor deze sport wordt alleen de tijd bijgehouden. Draag je Watch voor hartslag en energie.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    recorder.start(selectedType)
                } label: {
                    Label("Start \(selectedType.displayName.lowercased())", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                if isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Workout wordt opgeslagen…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: Opname

    private var recordingView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 4) {
                Text(Format.duration(recorder.elapsed))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(recorder.state == .paused ? "Gepauzeerd" : "Tijd")
                    .font(.subheadline)
                    .foregroundStyle(recorder.state == .paused ? Color.accentColor : Color.secondary)
            }

            if recorder.type.usesGPS {
                HStack {
                    StatTile(title: "Afstand", value: Format.distance(recorder.distanceMeters))
                    StatTile(
                        title: recorder.type.prefersSpeed ? "Snelheid" : "Tempo",
                        value: Format.paceOrSpeed(
                            type: recorder.type,
                            distanceMeters: recorder.distanceMeters,
                            durationSeconds: recorder.elapsed
                        ) ?? "–"
                    )
                }
                .padding(.horizontal, 32)

                if recorder.locationDenied {
                    Label("Geen toegang tot je locatie. Zet die aan bij Instellingen om je route vast te leggen.", systemImage: "location.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                } else if !recorder.hasGPSFix {
                    Label("GPS-signaal zoeken…", systemImage: "location")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 40) {
                Button {
                    confirmStop = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .frame(width: 76, height: 76)
                        .foregroundStyle(.white)
                        .background(Color.red, in: Circle())
                }
                .accessibilityLabel("Stop")

                Button {
                    if recorder.state == .paused {
                        recorder.resume()
                    } else {
                        recorder.pause()
                    }
                } label: {
                    Image(systemName: recorder.state == .paused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(width: 76, height: 76)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: Circle())
                }
                .accessibilityLabel(recorder.state == .paused ? "Hervat" : "Pauzeer")
            }
            .padding(.bottom, 32)
        }
        .confirmationDialog("Workout beëindigen?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Bewaar workout") {
                finish()
            }
            Button("Gooi weg", role: .destructive) {
                recorder.discard()
            }
            Button("Ga door", role: .cancel) {}
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
