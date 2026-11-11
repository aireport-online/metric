import Foundation
import Combine
import SwiftData
import MetricCore

/// Synchroniseert de lokale SwiftData-opslag met de server.
///
/// Volgorde: lokale verwijderingen → lokale wijzigingen → nieuwe activiteiten uploaden → servertoestand ophalen.
/// Zolang een record nog lokale wijzigingen heeft, wint de lokale versie.
@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastSyncedAt: Date?

    private let context: ModelContext
    private let uploadChunkSize = 10

    init(context: ModelContext) {
        self.context = context
    }

    func allRecords() -> [ActivityRecord] {
        (try? context.fetch(FetchDescriptor<ActivityRecord>())) ?? []
    }

    var pendingCount: Int {
        allRecords().filter { $0.syncState != .synced }.count
    }

    func save() {
        try? context.save()
    }

    /// Voert een volledige sync uit. Geeft de fout terug als het misging (bv. om op 401 te reageren).
    @discardableResult
    func sync(api: APIClient) async -> Error? {
        guard !isSyncing else { return nil }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await pushDeletes(api)
            try await pushUpdates(api)
            try await pushUploads(api)
            try await pull(api)
            try context.save()
            lastErrorMessage = nil
            lastSyncedAt = Date()
            return nil
        } catch {
            try? context.save()
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return error
        }
    }

    func deleteEverything() {
        for record in allRecords() {
            context.delete(record)
        }
        try? context.save()
        lastSyncedAt = nil
        lastErrorMessage = nil
    }

    // MARK: Stappen

    private func pushDeletes(_ api: APIClient) async throws {
        let records = allRecords().filter { $0.syncState == .pendingDelete }
        for record in records {
            if let serverId = record.serverId {
                do {
                    try await api.deleteActivity(id: serverId)
                } catch let error as APIError where error.isNotFound {
                    // Was al weg op de server.
                }
            }
            context.delete(record)
        }
    }

    private func pushUpdates(_ api: APIClient) async throws {
        let records = allRecords().filter { $0.syncState == .pendingUpdate }
        for record in records {
            guard let serverId = record.serverId else {
                record.syncState = .pendingUpload
                continue
            }
            let update = ActivityUpdate(
                title: record.title,
                notes: record.notes,
                visibility: record.visibility,
                type: record.type
            )
            do {
                let updated = try await api.updateActivity(id: serverId, update)
                if record.syncState == .pendingUpdate {
                    record.apply(updated)
                    record.syncState = .synced
                }
            } catch let error as APIError where error.isNotFound {
                // Op de server verwijderd (bv. via de website).
                context.delete(record)
            }
        }
    }

    private func pushUploads(_ api: APIClient) async throws {
        let pending = allRecords()
            .filter { $0.syncState == .pendingUpload }
            .sorted { $0.startedAt < $1.startedAt }
        var index = 0
        while index < pending.count {
            let end = min(index + uploadChunkSize, pending.count)
            let chunk = Array(pending[index..<end])
            let uploaded = try await api.uploadActivities(chunk.map { $0.makeInput() })
            var byClientId: [String: Activity] = [:]
            for activity in uploaded {
                byClientId[ClientID.normalize(activity.clientId)] = activity
            }
            for record in chunk {
                guard let activity = byClientId[record.clientId] else { continue }
                if record.syncState == .pendingUpload {
                    record.apply(activity)
                    record.syncState = .synced
                } else {
                    // Tijdens het uploaden lokaal gewijzigd of verwijderd: onthoud alleen het server-ID.
                    record.serverId = activity.id
                }
            }
            index = end
        }
    }

    private func pull(_ api: APIClient) async throws {
        var remote: [Activity] = []
        var cursor: String?
        var complete = false
        for _ in 0..<100 {
            let page = try await api.activities(before: cursor, limit: 100)
            remote.append(contentsOf: page.activities)
            if let next = page.nextCursor, !page.activities.isEmpty {
                cursor = next
            } else {
                complete = true
                break
            }
        }

        let local = allRecords()
        var byClientId: [String: ActivityRecord] = [:]
        for record in local {
            byClientId[record.clientId] = record
        }

        var remoteClientIds = Set<String>()
        for activity in remote {
            let key = ClientID.normalize(activity.clientId)
            remoteClientIds.insert(key)
            if let record = byClientId[key] {
                if record.syncState == .synced {
                    record.apply(activity)
                } else if record.serverId == nil {
                    record.serverId = activity.id
                }
            } else {
                let record = ActivityRecord(remote: activity)
                context.insert(record)
                byClientId[key] = record
            }
        }

        // Wat gesynchroniseerd was maar niet meer op de server staat, is elders verwijderd.
        if complete {
            for record in local where record.syncState == .synced && record.serverId != nil {
                if !remoteClientIds.contains(record.clientId) {
                    context.delete(record)
                }
            }
        }
    }
}
