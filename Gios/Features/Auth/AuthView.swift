import SwiftUI

/// Log in / sign up on one screen.
struct AuthView: View {
    enum Mode: String, CaseIterable { case login = "Log in", signup = "Sign up" }

    @Environment(AppEnvironment.self) private var env
    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var error: String?
    @FocusState private var focus: Field?
    enum Field { case name, email, password }

    private var isValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        switch mode {
        case .login: return emailOK && !password.isEmpty
        case .signup: return emailOK && password.count >= 8 && name.trimmingCharacters(in: .whitespaces).count >= 2
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(mode == .login ? "Welcome back" : "Join your campus")
                        .font(Theme.Fonts.display(32))
                    Text(mode == .login ? "Log in to see your friends and spots nearby."
                                        : "Find friends, discover spots, earn XP.")
                        .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, 40)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: Theme.Spacing.s + 4) {
                    if mode == .signup {
                        field("Name", text: $name, icon: "person")
                            .textContentType(.name)
                            .focused($focus, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focus = .email }
                    }
                    field("Email", text: $email, icon: "envelope")
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    HStack {
                        Image(systemName: "lock").foregroundStyle(Theme.Colors.textSecondary).frame(width: 22)
                        SecureField(mode == .signup ? "Password (8+ characters)" : "Password", text: $password)
                            .textContentType(mode == .signup ? .newPassword : .password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await submit() } }
                    }
                    .padding(14)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isWorking { ProgressView().tint(.white) } else { Text(mode.rawValue) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid || isWorking)

                #if DEBUG
                Button("Use demo account") {
                    mode = .login
                    email = "demo@gios.app"
                    password = "campus123"
                }
                .font(Theme.Fonts.caption)
                .frame(maxWidth: .infinity)
                #endif
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: mode) { error = nil }
    }

    private func field(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Theme.Colors.textSecondary).frame(width: 22)
            TextField(placeholder, text: text)
        }
        .padding(14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private func submit() async {
        guard isValid, !isWorking else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            switch mode {
            case .login: try await env.session.login(email: email, password: password)
            case .signup: try await env.session.signup(name: name.trimmingCharacters(in: .whitespaces), email: email, password: password)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview { AuthView().environment(AppEnvironment()) }
