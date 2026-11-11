import SwiftUI
import MetricCore

/// Kudos en reacties van een activiteit, als secties voor in een `List`.
/// Laadt het detail van de server; vult optioneel de route van een lokaal record aan.
struct ActivitySocialSections: View {
    @EnvironmentObject private var app: AppModel

    let activityId: String
    var loadsRouteInto: ActivityRecord?
    /// Wordt aangeroepen als het aantal kudos of reacties verandert (bv. om de feed bij te werken).
    var onChange: ((_ kudosCount: Int, _ hasKudoed: Bool, _ commentCount: Int) -> Void)?

    @State private var kudosCount = 0
    @State private var hasKudoed = false
    @State private var comments: [Comment] = []
    @State private var draft = ""
    @State private var isLoaded = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            Section {
                HStack {
                    KudosButton(count: kudosCount, hasKudoed: hasKudoed, title: kudosLabel) {
                        toggleKudos()
                    }
                    .disabled(!isLoaded)
                    Spacer()
                }
                .task(id: activityId) {
                    await load()
                }
            }
            .metricRow()

            Section {
                if isLoaded && comments.isEmpty {
                    Text("Nog geen reacties. Schrijf de eerste.")
                        .font(.metricText(15))
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(comment.user.displayName)
                                .font(.metricText(14, weight: .semibold))
                            Spacer()
                            Text(comment.createdAt.formatted(.relative(presentation: .named)))
                                .font(.metricText(12))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Text(comment.body)
                            .font(.metricText(16))
                    }
                    .swipeActions(edge: .trailing) {
                        if comment.user.id == app.me?.id {
                            Button(role: .destructive) {
                                delete(comment)
                            } label: {
                                Label("Verwijder", systemImage: "trash")
                            }
                        }
                    }
                }
                HStack {
                    TextField("Schrijf een reactie", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.tartan)
                    }
                    .buttonStyle(.borderless)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    .accessibilityLabel("Verstuur reactie")
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.metricText(13))
                        .foregroundStyle(Theme.danger)
                }
            } header: {
                SectionHeader("Reacties")
            }
            .metricRow()
        }
    }

    private var kudosLabel: String {
        switch kudosCount {
        case 0: return "Geef kudos"
        case 1: return "1 kudos"
        default: return "\(kudosCount) kudos"
        }
    }

    private func notifyChange() {
        onChange?(kudosCount, hasKudoed, comments.count)
        if let record = loadsRouteInto {
            record.kudosCount = kudosCount
            record.commentCount = comments.count
        }
    }

    private func load() async {
        do {
            let detail = try await app.api.activityDetail(id: activityId)
            kudosCount = detail.activity.kudosCount
            hasKudoed = detail.activity.hasKudoed
            comments = detail.comments
            isLoaded = true
            errorMessage = nil
            if let record = loadsRouteInto {
                record.kudosCount = detail.activity.kudosCount
                record.commentCount = detail.comments.count
                if record.routeData == nil, let route = detail.activity.route, route.count >= 2 {
                    record.setRoute(route)
                }
                app.sync.save()
            }
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func toggleKudos() {
        let give = !hasKudoed
        // Optimistisch bijwerken; bij een fout draaien we het terug.
        hasKudoed = give
        kudosCount = max(0, kudosCount + (give ? 1 : -1))
        Task {
            do {
                let response: KudosResponse
                if give {
                    response = try await app.api.giveKudos(activityId: activityId)
                } else {
                    response = try await app.api.removeKudos(activityId: activityId)
                }
                kudosCount = response.kudosCount
                hasKudoed = response.hasKudoed
                errorMessage = nil
            } catch {
                hasKudoed = !give
                kudosCount = max(0, kudosCount + (give ? -1 : 1))
                errorMessage = error.userMessage
            }
            notifyChange()
        }
    }

    private func send() {
        let body = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !body.isEmpty else { return }
        isSending = true
        Task {
            do {
                let comment = try await app.api.addComment(activityId: activityId, body: body)
                comments.append(comment)
                draft = ""
                errorMessage = nil
                notifyChange()
            } catch {
                errorMessage = error.userMessage
            }
            isSending = false
        }
    }

    private func delete(_ comment: Comment) {
        Task {
            do {
                try await app.api.deleteComment(id: comment.id)
                comments.removeAll { $0.id == comment.id }
                notifyChange()
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

/// Detail van een activiteit van iemand anders (uit de feed of een profiel).
struct RemoteActivityDetailView: View {
    @EnvironmentObject private var app: AppModel

    let activity: Activity
    var onChange: ((_ kudosCount: Int, _ hasKudoed: Bool, _ commentCount: Int) -> Void)?

    @State private var route: [[Double]] = []

    private var shareURL: URL? {
        guard activity.visibility != .private else { return nil }
        return app.webURL("/activities/\(activity.id)")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        UserAvatar(name: activity.user.displayName, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(activity.user.displayName)
                                .font(.metricText(15, weight: .semibold))
                            Text(activity.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.metricText(13))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    HStack(spacing: 8) {
                        SportStripe(type: activity.type)
                        Image(systemName: activity.type.symbolName)
                            .foregroundStyle(activity.type.tint)
                            .accessibilityHidden(true)
                        Text(activity.type.displayName)
                            .font(.metricLabel(17))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ActivityHeroFigure(
                        type: activity.type,
                        durationSeconds: activity.durationSeconds,
                        distanceMeters: activity.distanceMeters
                    )
                    ActivityStatsGrid(
                        type: activity.type,
                        durationSeconds: activity.durationSeconds,
                        distanceMeters: activity.distanceMeters,
                        elevationGainMeters: activity.elevationGainMeters,
                        activeEnergyKcal: activity.activeEnergyKcal,
                        avgHeartRate: activity.avgHeartRate,
                        maxHeartRate: activity.maxHeartRate
                    )
                }
                .padding(.vertical, 6)
            }
            .metricRow()

            if route.count >= 2 {
                Section {
                    RouteMapView(route: route)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if !activity.notes.isEmpty {
                Section {
                    Text(activity.notes)
                        .font(.metricText(16))
                } header: {
                    SectionHeader("Notitie")
                }
                .metricRow()
            }

            ActivitySocialSections(activityId: activity.id, onChange: onChange)
        }
        .metricListBackground()
        .navigationTitle(activity.title.isEmpty ? activity.type.displayName : activity.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let shareURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareURL) {
                        Label("Deel", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: activity.id) {
            guard activity.hasRoute else { return }
            if let detail = try? await app.api.activityDetail(id: activity.id), let loaded = detail.activity.route {
                route = loaded
            }
        }
    }
}
