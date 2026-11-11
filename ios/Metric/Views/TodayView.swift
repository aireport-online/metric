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

    /// Aantal verschillende dagen in de lopende week met minstens één activiteit.
    private var activeDaysThisWeek: Int {
        let calendar = StatsCalculator.mondayCalendar()
        let weekStart = StatsCalculator.weekStart(for: Date(), calendar: calendar)
        var days = Set<Date>()
        for record in records where record.startedAt >= weekStart {
            days.insert(calendar.startOfDay(for: record.startedAt))
        }
        return days.count
    }

    var body: some View {
        let weeks = StatsCalculator.weekly(samples, weeks: 8)
        let thisWeek = weeks.last
        let minutes = Int(((thisWeek?.durationSeconds ?? 0) / 60).rounded())
        let streak = StatsCalculator.streakWeeks(samples)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeekTrackCard(
                    minutes: minutes,
                    goalMinutes: goalMinutes,
                    distanceMeters: thisWeek?.distanceMeters ?? 0,
                    activeDays: activeDaysThisWeek,
                    streakWeeks: streak
                )
                .entrance(0)

                if app.health.isAvailable && !app.healthEnabled {
                    HealthPromptCard()
                        .entrance(1)
                }

                WeeklyChartCard(weeks: weeks, goalMinutes: goalMinutes)
                    .entrance(2)

                RecentCard(records: Array(records.prefix(5)))
                    .entrance(3)

                if let message = sync.lastErrorMessage {
                    Label(message, systemImage: "exclamationmark.icloud")
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
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

/// De week als atletiekbaan: de buitenbaan is het weekdoel, de binnenbaan het aantal actieve dagen.
private struct WeekTrackCard: View {
    let minutes: Int
    let goalMinutes: Int
    let distanceMeters: Double
    let activeDays: Int
    let streakWeeks: Int

    private var progress: Double {
        goalMinutes > 0 ? Double(minutes) / Double(goalMinutes) : 0
    }

    private var goalReached: Bool {
        goalMinutes > 0 && minutes >= goalMinutes
    }

    private var statusText: String {
        if goalReached {
            return "Weekdoel gehaald."
        }
        let remaining = goalMinutes - minutes
        return remaining == 1 ? "Nog 1 minuut tot je weekdoel." : "Nog \(remaining) minuten tot je weekdoel."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Deze week")
                    .font(.metricHeading(24))
                Spacer()
                if goalReached {
                    Label("Finish", systemImage: "flag.checkered")
                        .font(.metricText(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Theme.volt, in: Capsule())
                        .transition(AnyTransition.scale.combined(with: AnyTransition.opacity))
                }
            }
            .animation(Theme.Motion.kick, value: goalReached)

            TrackProgressView(
                lanes: [
                    TrackLane(progress: progress, color: Theme.tartan),
                    TrackLane(progress: Double(activeDays) / 7, color: Theme.text),
                ],
                goalReached: goalReached
            ) {
                VStack(spacing: -2) {
                    CountUp(value: Double(minutes))
                        .font(.metricNumber(56))
                        .foregroundStyle(Theme.text)
                    Text("van \(goalMinutes) min")
                        .font(.metricLabel(15))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weekdoel")
            .accessibilityValue("\(minutes) van \(goalMinutes) minuten, \(activeDays) van 7 dagen actief")

            Text(statusText)
                .font(.metricText(15))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                StatTile(title: "dagen actief", value: "\(activeDays)", unit: "/7", size: 32)
                StatTile(title: "afstand", value: Format.kilometers(distanceMeters), unit: "km", size: 32)
                StatTile(
                    title: streakWeeks == 1 ? "week op rij" : "weken op rij",
                    value: "\(streakWeeks)",
                    size: 32,
                    tint: streakWeeks > 0 ? Theme.volt : Theme.text
                )
            }
        }
        .metricCard()
    }
}

/// Minuten per week; de lopende week in tartan, het doel als baanlijn.
private struct WeeklyChartCard: View {
    let weeks: [WeekBucket]
    let goalMinutes: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var maxMinutes: Double {
        let highest = weeks.map { $0.durationSeconds / 60 }.max() ?? 0
        return max(highest, Double(goalMinutes)) * 1.15 + 1
    }

    var body: some View {
        let currentStart = weeks.last?.weekStart

        VStack(alignment: .leading, spacing: 12) {
            Text("Minuten per week")
                .font(.metricHeading(24))

            Chart {
                ForEach(weeks) { week in
                    BarMark(
                        x: .value("Week van", WeeklyChartCard.labelFormatter.string(from: week.weekStart)),
                        y: .value("Minuten", grown ? week.durationSeconds / 60 : 0),
                        width: .ratio(0.62)
                    )
                    .foregroundStyle(week.weekStart == currentStart ? Theme.tartan : Theme.lineStrong)
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Weekdoel", Double(goalMinutes)))
                    .foregroundStyle(Theme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: 0...maxMinutes)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.line)
                    AxisValueLabel()
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Minuten sport per week, afgelopen 8 weken")

            HStack(spacing: 14) {
                ChartLegendItem(color: Theme.tartan, label: "Deze week")
                ChartLegendItem(color: Theme.lineStrong, label: "Eerdere weken")
                Spacer(minLength: 0)
            }
            Text("Stippellijn: weekdoel van \(goalMinutes) minuten.")
                .font(.metricText(12))
                .foregroundStyle(Theme.textMuted)
        }
        .metricCard()
        .onAppear {
            if reduceMotion {
                grown = true
            } else {
                withAnimation(Theme.Motion.lap.delay(0.15)) {
                    grown = true
                }
            }
        }
    }
}

private struct ChartLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.metricText(12))
                .foregroundStyle(Theme.textMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RecentCard: View {
    let records: [ActivityRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent")
                .font(.metricHeading(24))
                .padding(.bottom, 6)

            if records.isEmpty {
                Text("Nog niets opgenomen. Start je eerste ronde via Opnemen, of begin een workout op je Watch.")
                    .font(.metricText(15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Rectangle()
                            .fill(Theme.line)
                            .frame(height: 1)
                    }
                    NavigationLink {
                        ActivityDetailView(record: record)
                    } label: {
                        ActivityRecordRow(record: record)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .metricCard()
    }
}

private struct HealthPromptCard: View {
    @EnvironmentObject private var app: AppModel
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Koppel Apple Gezondheid", systemImage: "heart.fill")
                .font(.metricHeading(22))
            Text("Dan verschijnen je workouts van de iPhone en Apple Watch hier vanzelf, met route en hartslag.")
                .font(.metricText(15))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                isBusy = true
                Task {
                    await app.enableHealth()
                    isBusy = false
                }
            } label: {
                if isBusy {
                    ProgressView()
                        .tint(Theme.ink)
                } else {
                    Text("Koppelen")
                }
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: false, compact: true))
            .disabled(isBusy)
        }
        .metricCard()
    }
}
