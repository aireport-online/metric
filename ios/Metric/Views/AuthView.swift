import SwiftUI
import MetricCore

struct AuthView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case login = "Inloggen"
        case register = "Account maken"

        var id: String { rawValue }
    }

    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var serverURL = ""
    @State private var showsAdvanced = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let hasCredentials = email.contains("@") && password.count >= 8
        switch mode {
        case .login:
            return hasCredentials
        case .register:
            return hasCredentials && username.count >= 3 && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .entrance(0)

                Picker("Wat wil je doen?", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .entrance(1)

                VStack(spacing: 12) {
                    TextField("E-mailadres", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .metricField()
                    SecureField("Wachtwoord", text: $password)
                        .textContentType(mode == .login ? .password : .newPassword)
                        .metricField()
                    if mode == .register {
                        TextField("Gebruikersnaam", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .metricField()
                            .transition(AnyTransition.opacity)
                        TextField("Naam", text: $displayName)
                            .textContentType(.name)
                            .metricField()
                            .transition(AnyTransition.opacity)
                        Text("Je wachtwoord heeft minimaal 8 tekens. Je gebruikersnaam is 3–20 tekens: letters, cijfers en _.")
                            .font(.metricText(13))
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(AnyTransition.opacity)
                    }
                }
                .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.base, value: mode)
                .entrance(2)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.metricText(14))
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    submit()
                } label: {
                    if isBusy {
                        ProgressView()
                            .tint(Theme.ink)
                    } else {
                        Text(mode == .login ? "Log in" : "Maak account")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid || isBusy)
                .entrance(3)

                advanced
                    .entrance(4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .onAppear {
            serverURL = app.serverURLString
        }
    }

    /// Beeldmerk, woordmerk en de baan die een ronde loopt.
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
                    .accessibilityHidden(true)
                Text("METRIC")
                    .font(.metricNumber(56))
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)
            }
            Text("Elke week een ronde.")
                .font(.metricHeading(26))
                .foregroundStyle(Theme.text)
            Text("Neem je sport op, zie je week en deel hem met vrienden.")
                .font(.metricText(16))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TrackProgressView(
                lanes: [
                    TrackLane(progress: 1, color: Theme.tartan),
                    TrackLane(progress: 0.72, color: Theme.text),
                    TrackLane(progress: 0.45, color: Theme.textSecondary),
                ],
                laneWidth: 8,
                aspect: 3.2,
                goalReached: true
            )
            .padding(.top, 6)
            .accessibilityHidden(true)
        }
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.base) {
                    showsAdvanced.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Geavanceerd")
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .rotationEffect(.degrees(showsAdvanced ? 180 : 0))
                }
                .font(.metricText(14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(PressableStyle())

            if showsAdvanced {
                TextField("Server-URL", text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .metricField()
                Text("Het adres van jouw Metric-server. Laat staan als je dit niet zelf host.")
                    .font(.metricText(13))
                    .foregroundStyle(Theme.textMuted)
                Button("Standaard herstellen") {
                    app.setServerURL("")
                    serverURL = app.serverURLString
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func submit() {
        guard app.setServerURL(serverURL) else {
            errorMessage = "De server-URL is ongeldig. Gebruik bijvoorbeeld https://metric.voorbeeld.nl."
            return
        }
        errorMessage = nil
        isBusy = true
        Task {
            do {
                switch mode {
                case .login:
                    try await app.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
                case .register:
                    try await app.register(
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password,
                        username: username.lowercased().trimmingCharacters(in: .whitespaces),
                        displayName: displayName.trimmingCharacters(in: .whitespaces)
                    )
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isBusy = false
        }
    }
}
