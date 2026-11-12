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
            .padding(.horizontal, 16)
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
        .background(Theme.bg)
        .navigationTitle("Vrienden")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: tab)
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
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.metricText(13))
                    .foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if hasLoaded && activities.isEmpty && errorMessage == nil {
                EmptyStateView(
                    symbol: "person.2",
                    title: "Nog niets te zien",
                    message: "Voeg vrienden toe via Vrienden. Hun activiteiten en die van jou verschijnen hier."
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                NavigationLink {
                    RemoteActivityDetailView(activity: activity, onChange: { kudosCount, hasKudoed, commentCount in
                        update(activity.id, kudosCount: kudosCount, hasKudoed: hasKudoed, commentCount: commentCount)
                    })
                } label: {
                    FeedRow(activity: activity, onKudos: {
                        toggleKudos(activity)
                    })
                }
                .entrance(index)
                .cardRow()
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
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                .disabled(isLoadingMore)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .metricListBackground()
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

/// Kudos-knop: het icoon veert, kleurt tartan en het aantal telt één op, met een lichte tik.
struct KudosButton: View {
    let count: Int
    let hasKudoed: Bool
    var title: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button {
            action()
            guard !reduceMotion else { return }
            withAnimation(Theme.Motion.kick) {
                pulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(Theme.Motion.kick) {
                    pulse = false
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasKudoed ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .scaleEffect(pulse ? 1.25 : 1)
                Text(title ?? "\(count)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.metricText(15, weight: .medium))
            .foregroundStyle(hasKudoed ? Theme.tartan : Theme.textSecondary)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(Theme.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.borderless)
        .animation(Theme.Motion.quick, value: count)
        .animation(Theme.Motion.quick, value: hasKudoed)
        .sensoryFeedback(.impact(weight: .light), trigger: hasKudoed)
        .onChange(of: hasKudoed) { _, isOn in
            if isOn { SoundPlayer.shared.play(.kudos) }
        }
        .accessibilityLabel(hasKudoed ? "Kudos intrekken" : "Geef kudos")
        .accessibilityValue("\(count) kudos")
    }
}

struct FeedRow: View {
    let activity: Activity
    var onKudos: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                UserAvatar(name: activity.user.displayName, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(activity.user.displayName)
                        .font(.metricText(15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(activity.startedAt.formatted(.relative(presentation: .named)))
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title.isEmpty ? activity.type.displayName : activity.title)
                        .font(.metricHeading(22))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        SportStripe(type: activity.type, height: 11)
                        Image(systemName: activity.type.symbolName)
                            .font(.caption)
                            .foregroundStyle(activity.type.tint)
                            .accessibilityHidden(true)
                        Text(activity.type.displayName)
                            .font(.metricText(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                ActivityRowFigure(durationSeconds: activity.durationSeconds, distanceMeters: activity.distanceMeters)
            }

            HStack(spacing: 10) {
                if let onKudos {
                    KudosButton(count: activity.kudosCount, hasKudoed: activity.hasKudoed, action: onKudos)
                        .accessibilityIdentifier("feed-kudos-\(activity.user.username)")
                } else {
                    Label("\(activity.kudosCount)", systemImage: "hand.thumbsup")
                        .foregroundStyle(Theme.textMuted)
                        .accessibilityLabel("\(activity.kudosCount) kudos")
                }
                Label("\(activity.commentCount)", systemImage: "bubble.left")
                    .foregroundStyle(Theme.textMuted)
                    .accessibilityLabel("\(activity.commentCount) reacties")
            }
            .font(.metricText(15, weight: .medium))
        }
    }
}

// MARK: - Ranglijst

/// De ranglijst als startopstelling: baannummers, en per deelnemer een baan die laat zien
/// hoe ver die is ten opzichte van de koploper.
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

            Section {
                if let board {
                    if board.entries.isEmpty {
                        Text("Nog niemand aan de start deze week.")
                            .font(.metricText(15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    let leaderValue = board.entries.map { $0.value }.max() ?? 0
                    ForEach(Array(board.entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(
                            entry: entry,
                            valueText: format(entry.value),
                            fraction: leaderValue > 0 ? entry.value / leaderValue : 0
                        )
                        .entrance(index)
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ProgressView()
                }
            } header: {
                SectionHeader("Deze week")
            }
            .metricRow()
        }
        .metricListBackground()
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

private struct LeaderboardRow: View {
    let entry: Leaderboard.Entry
    let valueText: String
    let fraction: Double

    private var numberColor: Color {
        if entry.rank == 1 {
            return Theme.volt
        }
        return entry.isMe ? Theme.tartan : Theme.textMuted
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.metricNumber(40))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .frame(width: 40, alignment: .leading)
                .accessibilityLabel("Plaats \(entry.rank)")
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.isMe ? "Jij" : entry.user.displayName)
                    .font(.metricText(16, weight: entry.isMe ? .semibold : .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(valueText)
                    .font(.metricLabel(16))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                Text(entry.count == 1 ? "1 activiteit" : "\(entry.count) activiteiten")
                    .font(.metricText(12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 8)
            TrackProgressView(
                lanes: [TrackLane(progress: fraction, color: entry.isMe ? Theme.tartan : Theme.text)],
                laneWidth: 5,
                aspect: 2.4
            )
            .frame(width: 72)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
                SectionHeader("Vriend toevoegen")
            }
            .metricRow()

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .metricRow()
            }

            if !incoming.isEmpty {
                Section {
                    ForEach(incoming) { request in
                        // De knoppen staan onder de naam: naast elkaar is er op een smal scherm
                        // te weinig ruimte en breken de naam en "Accepteer" af.
                        VStack(alignment: .leading, spacing: 10) {
                            UserLabel(user: request.user)
                            HStack(spacing: 8) {
                                Button("Accepteer") {
                                    perform {
                                        _ = try await app.api.acceptFriendRequest(id: request.id)
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(fullWidth: false, compact: true))
                                Button("Weiger") {
                                    perform {
                                        try await app.api.deleteFriendRequest(id: request.id)
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    SectionHeader("Verzoeken")
                }
                .metricRow()
            }

            Section {
                if hasLoaded && friends.isEmpty {
                    Text("Nog geen vrienden toegevoegd. Zoek hierboven of deel je profiel-link.")
                        .font(.metricText(15))
                        .foregroundStyle(Theme.textSecondary)
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
            } header: {
                SectionHeader("Vrienden")
            }
            .metricRow()

            if !outgoing.isEmpty {
                Section {
                    ForEach(outgoing) { request in
                        HStack {
                            UserLabel(user: request.user)
                            Spacer()
                            Button("Trek in") {
                                perform {
                                    try await app.api.deleteFriendRequest(id: request.id)
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                } header: {
                    SectionHeader("Verstuurd")
                }
                .metricRow()
            }
        }
        .metricListBackground()
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
                .font(.metricText(13))
                .foregroundStyle(Theme.textMuted)
        case .friends:
            Text("Vrienden")
                .font(.metricText(13))
                .foregroundStyle(Theme.textMuted)
        case .outgoing:
            Text("Verstuurd")
                .font(.metricText(13))
                .foregroundStyle(Theme.textMuted)
        case .incoming, .notConnected:
            Button(user.relation == .incoming ? "Accepteer" : "Voeg toe") {
                perform {
                    _ = try await app.api.sendFriendRequest(username: user.username)
                }
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: false, compact: true))
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
            UserAvatar(name: user.displayName)
            VStack(alignment: .leading, spacing: 0) {
                Text(user.displayName)
                    .font(.metricText(16, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text("@\(user.username)")
                    .font(.metricText(13))
                    .foregroundStyle(Theme.textMuted)
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
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            UserAvatar(name: profile.user.displayName, size: 52)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(profile.user.displayName)
                                    .font(.metricHeading(28))
                                Text("@\(profile.user.username)")
                                    .font(.metricText(14))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        if !profile.user.bio.isEmpty {
                            Text(profile.user.bio)
                                .font(.metricText(15))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        HStack(alignment: .top) {
                            StatTile(title: "activiteiten", value: "\(profile.stats.count)", size: 32)
                            StatTile(title: "afstand", value: Format.kilometers(profile.stats.distanceMeters), unit: "km", size: 32)
                            StatTile(title: "tijd", value: Format.decimal(profile.stats.durationSeconds / 3600, decimals: 1), unit: "u", size: 32)
                        }
                        relationButton(profile)
                    }
                    .padding(.vertical, 6)
                }
                .metricRow()

                Section {
                    if profile.activities.isEmpty {
                        Text("Geen activiteiten die je mag zien.")
                            .font(.metricText(15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(profile.activities) { activity in
                        NavigationLink {
                            RemoteActivityDetailView(activity: activity)
                        } label: {
                            FeedRow(activity: activity)
                                .padding(.vertical, 4)
                        }
                    }
                } header: {
                    SectionHeader("Activiteiten")
                }
                .metricRow()
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.metricText(15))
                    .foregroundStyle(Theme.textSecondary)
                    .metricRow()
            } else {
                ProgressView()
                    .listRowBackground(Color.clear)
            }
        }
        .metricListBackground()
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
                .font(.metricText(14))
                .foregroundStyle(Theme.textSecondary)
        case .outgoing:
            Label("Verzoek verstuurd", systemImage: "paperplane")
                .font(.metricText(14))
                .foregroundStyle(Theme.textSecondary)
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
            .buttonStyle(PrimaryButtonStyle())
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
