import SwiftUI
import SwiftData
import Charts
import MetricCore

struct TodayView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var sync: SyncService
    @Query(sort: \ActivityRecord.startedAt, order: .reverse) private var allRecords: [ActivityRecord]

    private var records: [ActivityRecord] {
        allRecords.filter { !$0.isPendingDelete }
    }

    private var samples: [ActivitySample] {
        records.map { $0.sample }
    }

    private var goalMinutes: Int {
        app.me?.weeklyGoalMinutes ?? 150
    }

    var body: some View {
        let weeks = StatsCalculator.weekly(samples, weeks: 8)
        let thisWeek = weeks.last
        let minutes = Int(((thisWeek?.durationSeconds ?? 0) / 60).rounded())
        let streak = StatsCalculator.streakWeeks(samples)

        List {
            Section {
                WeekGoalCard(
                    minutes: minutes,
                    goalMinutes: goalMinutes,
                    distanceMeters: thisWeek?.distanceMeters ?? 0,
                    count: thisWeek?.count ?? 0,
                    streakWeeks: streak
                )
            }

            if app.health.isAvailable && !app.healthEnabled {
                Section {
                    HealthPromptCard()
                }
            }

            Section("Afgelopen 8 weken") {
                WeeklyChart(weeks: weeks, goalMinutes: goalMinutes)
                    .frame(height: 180)
                    .padding(.vertical, 8)
            }

            Section("Recent") {
                if records.isEmpty {
                    Text("Nog geen activiteiten. Neem er een op via het tabblad Opnemen, of start een workout op je Watch.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records.prefix(5)) { record in
                        NavigationLink {
                            ActivityDetailView(record: record)
                        } label: {
                            ActivityRecordRow(record: record)
                        }
                    }
                }
            }

            if let message = sync.lastErrorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.icloud")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(greeting)
        .refreshable {
            await app.refreshAll()
        }
    }

    private var greeting: String {
        if let name = app.me?.displayName.split(separator: " ").first {
            return "Hoi \(name)"
        }
        return "Vandaag"
    }
}

private struct WeekGoalCard: View {
    let minutes: Int
    let goalMinutes: Int
    let distanceMeters: Double
    let count: Int
    let streakWeeks: Int

    private var progress: Double {
        goalMinutes > 0 ? Double(minutes) / Double(goalMinutes) : 0
    }

    private var remainingText: String {
        if minutes >= goalMinutes {
            return "Weekdoel gehaald 🎉"
        }
        return "Nog \(goalMinutes - minutes) min tot je weekdoel"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 14)
                    VStack(spacing: 0) {
                        Text("\(minutes)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("van \(goalMinutes) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Deze week")
                        .font(.headline)
                    Text(remainingText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if streakWeeks > 0 {
                        Label(streakWeeks == 1 ? "1 week op rij" : "\(streakWeeks) weken op rij", systemImage: "flame.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            HStack {
                StatTile(title: "Activiteiten", value: "\(count)")
                StatTile(title: "Afstand", value: Format.distance(distanceMeters))
                StatTile(title: "Tijd", value: Format.durationShort(Double(minutes) * 60))
            }
        }
        .padding(.vertical, 8)
    }
}

private struct WeeklyChart: View {
    let weeks: [WeekBucket]
    let goalMinutes: Int

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        Chart {
            ForEach(weeks) { week in
                BarMark(
                    x: .value("Week van", WeeklyChart.labelFormatter.string(from: week.weekStart)),
                    y: .value("Minuten", week.durationSeconds / 60)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(4)
            }
            RuleMark(y: .value("Weekdoel", Double(goalMinutes)))
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYAxisLabel("minuten")
        .accessibilityLabel("Minuten sport per week, afgelopen 8 weken")
    }
}

private struct HealthPromptCard: View {
    @EnvironmentObject private var app: AppModel
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Koppel Apple Gezondheid", systemImage: "heart.fill")
                .font(.headline)
            Text("Dan verschijnen je workouts van de iPhone en Apple Watch hier automatisch, inclusief route en hartslag.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                isBusy = true
                Task {
                    await app.enableHealth()
                    isBusy = false
                }
            } label: {
                if isBusy {
                    ProgressView()
                } else {
                    Text("Koppelen")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        }
        .padding(.vertical, 6)
    }
}
