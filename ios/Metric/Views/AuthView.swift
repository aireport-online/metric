import SwiftUI
import MetricCore

struct AuthView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case login = "Inloggen"
        case register = "Account maken"

        var id: String { rawValue }
    }

    @EnvironmentObject private var app: AppModel

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var serverURL = ""
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
        NavigationStack {
            Form {
                Section {
                    Picker("Wat wil je doen?", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    TextField("E-mailadres", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Wachtwoord", text: $password)
                        .textContentType(mode == .login ? .password : .newPassword)
                    if mode == .register {
                        TextField("Gebruikersnaam", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Naam", text: $displayName)
                            .textContentType(.name)
                    }
                } footer: {
                    if mode == .register {
                        Text("Je wachtwoord heeft minimaal 8 tekens. Je gebruikersnaam is 3–20 tekens: letters, cijfers en _.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isBusy {
                                ProgressView()
                            } else {
                                Text(mode == .login ? "Log in" : "Maak account")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isBusy)
                }

                Section {
                    DisclosureGroup("Geavanceerd") {
                        TextField("Server-URL", text: $serverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Standaard herstellen") {
                            app.setServerURL("")
                            serverURL = app.serverURLString
                        }
                    }
                } footer: {
                    Text("Het adres van jouw Metric-server. Laat staan als je dit niet zelf host.")
                }
            }
            .navigationTitle("Metric")
            .onAppear {
                serverURL = app.serverURLString
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
