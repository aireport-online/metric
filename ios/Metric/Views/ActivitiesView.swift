import SwiftUI
import SwiftData
import MetricCore

struct ActivitiesView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var sync: SyncService
    @Query(sort: \ActivityRecord.startedAt, order: .reverse) private var allRecords: [ActivityRecord]

    private var records: [ActivityRecord] {
        allRecords.filter { !$0.isPendingDelete }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    symbol: "figure.run",
                    title: "Nog geen activiteiten",
                    message: "Neem een workout op met je iPhone of Watch, of koppel Apple Gezondheid op het tabblad Vandaag."
                )
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink {
                            ActivityDetailView(record: record)
                        } label: {
                            ActivityRecordRow(record: record)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                app.delete(record)
                            } label: {
                                Label("Verwijder", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    await app.refreshAll()
                }
            }
        }
        .navigationTitle("Activiteiten")
        .toolbar {
            if sync.isSyncing {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                }
            }
        }
    }
}

struct ActivityDetailView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    let record: ActivityRecord

    @State private var isEditing = false
    @State private var confirmDelete = false

    private var shareURL: URL? {
        guard let serverId = record.serverId, record.visibility != .private else { return nil }
        return app.webURL("/activities/\(serverId)")
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ActivityIcon(type: record.type, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.type.displayName)
                            .font(.headline)
                        Text(record.startedAt.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ActivityStatsGrid(
                    type: record.type,
                    durationSeconds: record.durationSeconds,
                    distanceMeters: record.distanceMeters,
                    elevationGainMeters: record.elevationGainMeters,
                    activeEnergyKcal: record.activeEnergyKcal,
                    avgHeartRate: record.avgHeartRate,
                    maxHeartRate: record.maxHeartRate
                )
            }

            let route = record.route
            if route.count >= 2 {
                Section {
                    RouteMapView(route: route)
                        .listRowInsets(EdgeInsets())
                }
            }

            if !record.notes.isEmpty {
                Section("Notitie") {
                    Text(record.notes)
                }
            }

            Section {
                LabeledContent("Zichtbaar voor") {
                    let visibility = record.visibility ?? app.me?.defaultVisibility ?? .friends
                    Label(visibility.displayName, systemImage: visibility.symbolName)
                }
                LabeledContent("Bron", value: record.source.displayName)
                if record.syncState != .synced {
                    Label("Wordt gesynchroniseerd zodra er verbinding is", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let serverId = record.serverId {
                ActivitySocialSections(activityId: serverId, loadsRouteInto: record)
            }

            Section {
                Button("Verwijder activiteit", role: .destructive) {
                    confirmDelete = true
                }
            }
        }
        .navigationTitle(record.title.isEmpty ? record.type.displayName : record.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Deel", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Wijzig") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditActivitySheet(record: record)
        }
        .confirmationDialog("Deze activiteit verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijder", role: .destructive) {
                app.delete(record)
                dismiss()
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("De activiteit verdwijnt ook van de website. In Gezondheid blijft hij staan.")
        }
    }
}

struct EditActivitySheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    let record: ActivityRecord

    @State private var title = ""
    @State private var notes = ""
    @State private var type: ActivityType = .other
    @State private var visibility: ActivityVisibility = .friends

    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("Titel", text: $title)
                }
                Section("Notitie") {
                    TextField("Hoe ging het?", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Picker("Sport", selection: $type) {
                        ForEach(ActivityType.allCases) { type in
                            Label(type.displayName, systemImage: type.symbolName).tag(type)
                        }
                    }
                    Picker("Zichtbaar voor", selection: $visibility) {
                        ForEach(ActivityVisibility.allCases) { visibility in
                            Text(visibility.displayName).tag(visibility)
                        }
                    }
                }
            }
            .navigationTitle("Wijzig activiteit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        save()
                    }
                }
            }
            .onAppear {
                title = record.title
                notes = record.notes
                type = record.type
                visibility = record.visibility ?? app.me?.defaultVisibility ?? .friends
            }
        }
    }

    private func save() {
        record.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        record.notes = String(notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        record.type = type
        record.visibility = visibility
        app.markEdited(record)
        dismiss()
    }
}
