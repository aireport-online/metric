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
                Button {
                    toggleKudos()
                } label: {
                    Label(kudosLabel, systemImage: hasKudoed ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .disabled(!isLoaded)
                .task(id: activityId) {
                    await load()
                }
            }

            Section("Reacties") {
                if isLoaded && comments.isEmpty {
                    Text("Nog geen reacties.")
                        .foregroundStyle(.secondary)
                }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(comment.user.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(comment.createdAt.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(comment.body)
                            .font(.body)
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
                    }
                    .buttonStyle(.borderless)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    .accessibilityLabel("Verstuur reactie")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
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
                HStack(spacing: 12) {
                    ActivityIcon(type: activity.type, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.user.displayName)
                            .font(.headline)
                        Text("\(activity.type.displayName) · \(activity.startedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
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

            if route.count >= 2 {
                Section {
                    RouteMapView(route: route)
                        .listRowInsets(EdgeInsets())
                }
            }

            if !activity.notes.isEmpty {
                Section("Notitie") {
                    Text(activity.notes)
                }
            }

            ActivitySocialSections(activityId: activity.id, onChange: onChange)
        }
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
