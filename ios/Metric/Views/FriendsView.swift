import SwiftUI
import MetricCore

struct FriendsView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case feed = "Feed"
        case leaderboard = "Ranglijst"
        case friends = "Vrienden"

        var id: String { rawValue }
    }

    @State private var tab: Segment = .feed

    var body: some View {
        VStack(spacing: 0) {
            Picker("Onderdeel", selection: $tab) {
                ForEach(Segment.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch tab {
            case .feed:
                FeedView()
            case .leaderboard:
                LeaderboardView()
            case .friends:
                FriendsListView()
            }
        }
        .navigationTitle("Vrienden")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feed

struct FeedView: View {
    @EnvironmentObject private var app: AppModel

    @State private var activities: [Activity] = []
    @State private var nextCursor: String?
    @State private var hasLoaded = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if hasLoaded && activities.isEmpty && errorMessage == nil {
                EmptyStateView(
                    symbol: "person.2",
                    title: "Nog niets te zien",
                    message: "Voeg vrienden toe via het tabblad Vrienden. Hun activiteiten en die van jou verschijnen hier."
                )
                .listRowBackground(Color.clear)
            }

            ForEach(activities) { activity in
                NavigationLink {
                    RemoteActivityDetailView(activity: activity, onChange: { kudosCount, hasKudoed, commentCount in
                        update(activity.id, kudosCount: kudosCount, hasKudoed: hasKudoed, commentCount: commentCount)
                    })
                } label: {
                    FeedRow(activity: activity, onKudos: {
                        toggleKudos(activity)
                    })
                }
            }

            if nextCursor != nil {
                Button {
                    Task {
                        await loadMore()
                    }
                } label: {
                    if isLoadingMore {
                        ProgressView()
                    } else {
                        Text("Meer laden")
                    }
                }
                .disabled(isLoadingMore)
            }
        }
        .overlay {
            if !hasLoaded && errorMessage == nil {
                ProgressView()
            }
        }
        .refreshable {
            await load()
        }
        .task {
            if !hasLoaded {
                await load()
            }
        }
    }

    private func load() async {
        do {
            let page = try await app.api.feed()
            activities = page.activities
            nextCursor = page.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
        hasLoaded = true
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let page = try await app.api.feed(before: cursor)
            let known = Set(activities.map { $0.id })
            activities.append(contentsOf: page.activities.filter { !known.contains($0.id) })
            nextCursor = page.activities.isEmpty ? nil : page.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
        isLoadingMore = false
    }

    private func update(_ id: String, kudosCount: Int, hasKudoed: Bool, commentCount: Int) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].kudosCount = kudosCount
        activities[index].hasKudoed = hasKudoed
        activities[index].commentCount = commentCount
    }

    private func toggleKudos(_ activity: Activity) {
        let give = !activity.hasKudoed
        update(
            activity.id,
            kudosCount: max(0, activity.kudosCount + (give ? 1 : -1)),
            hasKudoed: give,
            commentCount: activity.commentCount
        )
        Task {
            do {
                let response: KudosResponse
                if give {
                    response = try await app.api.giveKudos(activityId: activity.id)
                } else {
                    response = try await app.api.removeKudos(activityId: activity.id)
                }
                update(activity.id, kudosCount: response.kudosCount, hasKudoed: response.hasKudoed, commentCount: activity.commentCount)
            } catch {
                update(activity.id, kudosCount: activity.kudosCount, hasKudoed: activity.hasKudoed, commentCount: activity.commentCount)
                errorMessage = error.userMessage
            }
        }
    }
}

struct FeedRow: View {
    let activity: Activity
    var onKudos: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(activity.user.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(activity.startedAt.formatted(.relative(presentation: .named)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ActivityIcon(type: activity.type)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title.isEmpty ? activity.type.displayName : activity.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(activitySummary(durationSeconds: activity.durationSeconds, distanceMeters: activity.distanceMeters))
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 16) {
                if let onKudos {
                    Button {
                        onKudos()
                    } label: {
                        Label("\(activity.kudosCount)", systemImage: activity.hasKudoed ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(activity.hasKudoed ? "Kudos intrekken" : "Geef kudos")
                    .accessibilityValue("\(activity.kudosCount) kudos")
                } else {
                    Label("\(activity.kudosCount)", systemImage: "hand.thumbsup")
                        .foregroundStyle(.secondary)
                }
                Label("\(activity.commentCount)", systemImage: "bubble.left")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(activity.commentCount) reacties")
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ranglijst

struct LeaderboardView: View {
    @EnvironmentObject private var app: AppModel

    @State private var metric: LeaderboardMetric = .duration
    @State private var board: Leaderboard?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Picker("Rangschik op", selection: $metric) {
                    ForEach(LeaderboardMetric.allCases) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Deze week") {
                if let board {
                    if board.entries.isEmpty {
                        Text("Nog geen activiteiten deze week.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(board.entries) { entry in
                        HStack(spacing: 12) {
                            Text("\(entry.rank)")
                                .font(.headline)
                                .monospacedDigit()
                                .frame(width: 28, alignment: .leading)
                                .foregroundStyle(entry.rank == 1 ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.isMe ? "\(entry.user.displayName) (jij)" : entry.user.displayName)
                                    .fontWeight(entry.isMe ? .semibold : .regular)
                                Text(entry.count == 1 ? "1 activiteit" : "\(entry.count) activiteiten")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(format(entry.value))
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
        }
        .refreshable {
            await load()
        }
        .task(id: metric) {
            await load()
        }
    }

    private func format(_ value: Double) -> String {
        switch metric {
        case .duration: return Format.durationShort(value)
        case .distance: return Format.distance(value)
        case .count: return "\(Int(value.rounded()))×"
        }
    }

    private func load() async {
        do {
            board = try await app.api.leaderboard(metric: metric)
            errorMessage = nil
        } catch {
            if board == nil {
                errorMessage = error.userMessage
            }
        }
    }
}

// MARK: - Vrienden beheren

struct FriendsListView: View {
    @EnvironmentObject private var app: AppModel

    @State private var friends: [UserSummary] = []
    @State private var incoming: [FriendRequest] = []
    @State private var outgoing: [FriendRequest] = []
    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var profileURL: URL? {
        guard let me = app.me else { return nil }
        return app.webURL("/u/\(me.username)")
    }

    var body: some View {
        List {
            Section {
                TextField("Zoek op naam of gebruikersnaam", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                ForEach(results) { user in
                    HStack {
                        UserLabel(user: user.summary)
                        Spacer()
                        relationControl(for: user)
                    }
                }
                if let profileURL {
                    ShareLink(item: profileURL) {
                        Label("Nodig uit met je profiel-link", systemImage: "link")
                    }
                }
            } header: {
                Text("Vriend toevoegen")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !incoming.isEmpty {
                Section("Verzoeken") {
                    ForEach(incoming) { request in
                        HStack {
                            UserLabel(user: request.user)
                            Spacer()
                            Button("Accepteer") {
                                perform {
                                    _ = try await app.api.acceptFriendRequest(id: request.id)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            Button("Weiger") {
                                perform {
                                    try await app.api.deleteFriendRequest(id: request.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("Vrienden") {
                if hasLoaded && friends.isEmpty {
                    Text("Je hebt nog geen vrienden toegevoegd.")
                        .foregroundStyle(.secondary)
                }
                ForEach(friends) { friend in
                    NavigationLink {
                        UserProfileView(username: friend.username)
                    } label: {
                        UserLabel(user: friend)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            perform {
                                try await app.api.removeFriend(userId: friend.id)
                            }
                        } label: {
                            Label("Verwijder", systemImage: "person.badge.minus")
                        }
                    }
                }
            }

            if !outgoing.isEmpty {
                Section("Verstuurd") {
                    ForEach(outgoing) { request in
                        HStack {
                            UserLabel(user: request.user)
                            Spacer()
                            Button("Trek in") {
                                perform {
                                    try await app.api.deleteFriendRequest(id: request.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .task(id: query) {
            await search()
        }
    }

    @ViewBuilder
    private func relationControl(for user: UserSearchResult) -> some View {
        switch user.relation {
        case .me:
            Text("Dat ben jij")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .friends:
            Text("Vrienden")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .outgoing:
            Text("Verstuurd")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .incoming, .notConnected:
            Button(user.relation == .incoming ? "Accepteer" : "Voeg toe") {
                perform {
                    _ = try await app.api.sendFriendRequest(username: user.username)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func load() async {
        do {
            let response = try await app.api.friends()
            friends = response.friends
            incoming = response.incoming
            outgoing = response.outgoing
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
        hasLoaded = true
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        // Kleine pauze zodat we niet bij elke toetsaanslag zoeken.
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled {
            return
        }
        if let users = try? await app.api.searchUsers(query: trimmed) {
            results = users
        }
    }

    /// Voert een actie uit en ververst daarna de lijsten en zoekresultaten.
    private func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                errorMessage = nil
            } catch {
                errorMessage = error.userMessage
            }
            await load()
            await search()
        }
    }
}

struct UserLabel: View {
    let user: UserSummary

    var body: some View {
        HStack(spacing: 10) {
            Text(String(user.displayName.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(user.displayName)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Profiel van een ander

struct UserProfileView: View {
    @EnvironmentObject private var app: AppModel

    let username: String

    @State private var profile: Profile?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let profile {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        UserLabel(user: UserSummary(id: profile.user.id, username: profile.user.username, displayName: profile.user.displayName))
                        if !profile.user.bio.isEmpty {
                            Text(profile.user.bio)
                                .font(.subheadline)
                        }
                    }
                    HStack {
                        StatTile(title: "Activiteiten", value: "\(profile.stats.count)")
                        StatTile(title: "Afstand", value: Format.distance(profile.stats.distanceMeters))
                        StatTile(title: "Tijd", value: Format.durationShort(profile.stats.durationSeconds))
                    }
                    relationButton(profile)
                }

                Section("Activiteiten") {
                    if profile.activities.isEmpty {
                        Text("Geen activiteiten die je mag zien.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(profile.activities) { activity in
                        NavigationLink {
                            RemoteActivityDetailView(activity: activity)
                        } label: {
                            FeedRow(activity: activity)
                        }
                    }
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func relationButton(_ profile: Profile) -> some View {
        switch profile.relation {
        case .me:
            EmptyView()
        case .friends:
            Label("Jullie zijn vrienden", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .outgoing:
            Label("Verzoek verstuurd", systemImage: "paperplane")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .incoming, .notConnected:
            Button(profile.relation == .incoming ? "Accepteer verzoek" : "Voeg toe als vriend") {
                Task {
                    do {
                        _ = try await app.api.sendFriendRequest(username: username)
                    } catch {
                        errorMessage = error.userMessage
                    }
                    await load()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func load() async {
        do {
            profile = try await app.api.profile(username: username)
            errorMessage = nil
        } catch {
            if profile == nil {
                errorMessage = error.userMessage
            }
        }
    }
}
