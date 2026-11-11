import SwiftUI
import MetricCore

struct ProfileView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var sync: SyncService

    @State private var displayName = ""
    @State private var bio = ""
    @State private var goalMinutes = 150
    @State private var visibility: ActivityVisibility = .friends
    @State private var isSaving = false
    @State private var isBusy = false
    @State private var message: String?
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var deletePassword = ""

    private var hasChanges: Bool {
        guard let me = app.me else { return false }
        return displayName != me.displayName
            || bio != me.bio
            || goalMinutes != me.weeklyGoalMinutes
            || visibility != me.defaultVisibility
    }

    private var profileURL: URL? {
        guard let me = app.me else { return nil }
        return app.webURL("/u/\(me.username)")
    }

    var body: some View {
        Form {
            Section("Profiel") {
                TextField("Naam", text: $displayName)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(1...4)
                if let me = app.me {
                    LabeledContent("Gebruikersnaam", value: "@\(me.username)")
                    LabeledContent("E-mailadres", value: me.email)
                }
            }

            Section {
                Stepper(value: $goalMinutes, in: 30...1200, step: 15) {
                    LabeledContent("Weekdoel", value: "\(goalMinutes) min")
                }
                Picker("Nieuwe activiteiten zichtbaar voor", selection: $visibility) {
                    ForEach(ActivityVisibility.allCases) { visibility in
                        Text(visibility.displayName).tag(visibility)
                    }
                }
            } header: {
                Text("Doel en delen")
            } footer: {
                Text("Vrienden zien je activiteiten in hun feed. Met 'Iedereen met de link' kun je een activiteit ook buiten Metric delen.")
            }

            if hasChanges {
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Bewaar wijzigingen")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let profileURL {
                Section {
                    ShareLink(item: profileURL) {
                        Label("Deel mijn profiel", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Vrienden kunnen je via deze link vinden en een vriendschapsverzoek sturen.")
                }
            }

            if app.health.isAvailable {
                Section("Apple Gezondheid") {
                    if app.healthEnabled {
                        Label("Gekoppeld", systemImage: "checkmark.circle.fill")
                        Button("Workouts opnieuw importeren") {
                            runBusy {
                                await app.reimportHealth()
                            }
                        }
                        .disabled(isBusy)
                    } else {
                        Button("Koppel Apple Gezondheid") {
                            runBusy {
                                await app.enableHealth()
                            }
                        }
                        .disabled(isBusy)
                    }
                }
            }

            Section("Synchronisatie") {
                LabeledContent("Laatst bijgewerkt") {
                    if sync.isSyncing {
                        ProgressView()
                    } else if let date = sync.lastSyncedAt {
                        Text(date.formatted(date: .omitted, time: .shortened))
                    } else {
                        Text("Nog niet")
                    }
                }
                if let error = sync.lastErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Nu synchroniseren") {
                    runBusy {
                        await app.refreshAll()
                    }
                }
                .disabled(isBusy || sync.isSyncing)
                LabeledContent("Server", value: app.serverURLString)
            }

            Section {
                Button("Log uit") {
                    confirmLogout = true
                }
                Button("Verwijder account", role: .destructive) {
                    deletePassword = ""
                    confirmDelete = true
                }
            }
        }
        .navigationTitle("Profiel")
        .onAppear {
            loadFromModel()
        }
        .onChange(of: app.me) { _, _ in
            if !isSaving {
                loadFromModel()
            }
        }
        .confirmationDialog("Uitloggen?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log uit", role: .destructive) {
                Task {
                    await app.logout()
                }
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Activiteiten die nog niet gesynchroniseerd zijn, worden eerst geüpload. Zonder verbinding gaan ze op dit toestel verloren (ze blijven wel in Gezondheid staan).")
        }
        .alert("Account verwijderen", isPresented: $confirmDelete) {
            SecureField("Wachtwoord", text: $deletePassword)
            Button("Verwijder definitief", role: .destructive) {
                deleteAccount()
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Je account, activiteiten, vrienden en reacties worden definitief verwijderd. Vul je wachtwoord in om te bevestigen.")
        }
    }

    private func loadFromModel() {
        guard let me = app.me else { return }
        displayName = me.displayName
        bio = me.bio
        goalMinutes = me.weeklyGoalMinutes
        visibility = me.defaultVisibility
    }

    private func saveProfile() {
        isSaving = true
        message = nil
        let update = MeUpdate(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            weeklyGoalMinutes: goalMinutes,
            defaultVisibility: visibility
        )
        Task {
            do {
                try await app.updateProfile(update)
            } catch {
                message = error.userMessage
            }
            isSaving = false
            loadFromModel()
        }
    }

    private func deleteAccount() {
        let password = deletePassword
        deletePassword = ""
        Task {
            do {
                try await app.deleteAccount(password: password)
            } catch {
                message = error.userMessage
            }
        }
    }

    private func runBusy(_ work: @escaping () async -> Void) {
        isBusy = true
        Task {
            await work()
            isBusy = false
        }
    }
}
