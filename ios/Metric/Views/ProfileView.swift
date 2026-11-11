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
            if let me = app.me {
                Section {
                    HStack(spacing: 14) {
                        UserAvatar(name: me.displayName, size: 56)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(me.displayName)
                                .font(.metricHeading(30))
                            Text("@\(me.username)")
                                .font(.metricText(14))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .metricRow()
            }

            Section {
                TextField("Naam", text: $displayName)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(1...4)
                if let me = app.me {
                    LabeledContent("E-mailadres") {
                        Text(me.email)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            } header: {
                SectionHeader("Profiel")
            }
            .metricRow()

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Weekdoel")
                        Spacer()
                        FigureText(value: "\(goalMinutes)", unit: "min", size: 32, tint: Theme.tartan)
                            .contentTransition(.numericText())
                            .animation(Theme.Motion.quick, value: goalMinutes)
                    }
                    Stepper("Weekdoel aanpassen", value: $goalMinutes, in: 30...1200, step: 15)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .sensoryFeedback(.selection, trigger: goalMinutes)
                }
                Picker("Nieuwe activiteiten zichtbaar voor", selection: $visibility) {
                    ForEach(ActivityVisibility.allCases) { visibility in
                        Text(visibility.displayName).tag(visibility)
                    }
                }
            } header: {
                SectionHeader("Doel en delen")
            } footer: {
                Text("Vrienden zien je activiteiten in hun feed. Met 'Iedereen met de link' kun je een activiteit ook buiten Metric delen.")
                    .font(.metricText(13))
                    .foregroundStyle(Theme.textMuted)
            }
            .metricRow()

            if hasChanges {
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(Theme.ink)
                        } else {
                            Text("Bewaar wijzigingen")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .metricRow()
            }

            if let profileURL {
                Section {
                    ShareLink(item: profileURL) {
                        Label("Deel mijn profiel", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Vrienden kunnen je via deze link vinden en een vriendschapsverzoek sturen.")
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textMuted)
                }
                .metricRow()
            }

            if app.health.isAvailable {
                Section {
                    if app.healthEnabled {
                        Label("Gekoppeld", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
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
                } header: {
                    SectionHeader("Apple Gezondheid")
                }
                .metricRow()
            }

            Section {
                LabeledContent("Laatst bijgewerkt") {
                    if sync.isSyncing {
                        ProgressView()
                    } else if let date = sync.lastSyncedAt {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Nog niet")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let error = sync.lastErrorMessage {
                    Text(error)
                        .font(.metricText(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Nu synchroniseren") {
                    runBusy {
                        await app.refreshAll()
                    }
                }
                .disabled(isBusy || sync.isSyncing)
                LabeledContent("Server") {
                    Text(app.serverURLString)
                        .foregroundStyle(Theme.textSecondary)
                }
            } header: {
                SectionHeader("Synchronisatie")
            }
            .metricRow()

            Section {
                Button("Log uit") {
                    confirmLogout = true
                }
                Button(role: .destructive) {
                    deletePassword = ""
                    confirmDelete = true
                } label: {
                    Text("Verwijder account")
                        .foregroundStyle(Theme.danger)
                }
            }
            .metricRow()
        }
        .metricListBackground()
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
