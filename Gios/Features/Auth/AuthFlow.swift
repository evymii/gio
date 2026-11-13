import SwiftUI

/// Welcome → Sign in / Create account, with push transitions.
struct AuthFlow: View {
    enum Route: Hashable { case login, signup }
    @State private var path: [Route] = AuthFlow.initialPath

    /// DEBUG: `-auth login|signup` opens a form directly (screenshots/QA).
    private static var initialPath: [Route] {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-auth"), i + 1 < args.count { return [args[i + 1] == "signup" ? .signup : .login] }
        #endif
        return []
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append($0) }
                .navigationDestination(for: Route.self) { route in
                    AuthFormView(mode: route == .login ? .login : .signup) { other in
                        path = [other == .login ? .login : .signup]
                    }
                }
        }
    }
}

struct WelcomeView: View {
    var go: (AuthFlow.Route) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PillCollage()
                .frame(maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                StackedTitle(primary: "Your campus,", secondary: "together.", size: 40)
                    .appear(delay: 0.4)
                VStack(spacing: 12) {
                    Button("Sign in") { go(.login) }.buttonStyle(PillButtonStyle(fill: .white))
                    Button("Create account") { go(.signup) }.buttonStyle(PillButtonStyle(outlined: true))
                }
                .appear(delay: 0.5)
            }
            .padding(Theme.Spacing.l)
        }
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Sign in / sign up form.
struct AuthFormView: View {
    enum Mode { case login, signup }
    let mode: Mode
    var switchTo: (Mode) -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isWorking = false
    @State private var error: String?
    @FocusState private var focus: Field?
    enum Field { case name, email, password }

    private var emailOK: Bool { email.contains("@") && email.contains(".") }
    private var isValid: Bool {
        switch mode {
        case .login: emailOK && !password.isEmpty
        case .signup: emailOK && password.count >= 8 && name.trimmingCharacters(in: .whitespaces).count >= 2
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                HStack(spacing: 10) {
                    LineBadge(mode == .login ? "IN" : "UP", color: mode == .login ? Theme.Colors.yellow : Theme.Colors.pink, size: 52)
                    ArrowBadge(systemName: "arrow.up.right", color: Theme.Colors.lavender, foreground: Theme.Colors.ink, size: 52)
                }
                .appear()
                StackedTitle(primary: mode == .login ? "Welcome" : "Join the",
                             secondary: mode == .login ? "Back" : "Campus", size: 52)
                    .appear(delay: 0.05)

                VStack(spacing: 12) {
                    if mode == .signup {
                        FieldBox(icon: "person.fill") {
                            TextField("Name", text: $name).textContentType(.name)
                                .focused($focus, equals: .name).submitLabel(.next).onSubmit { focus = .email }
                        }
                    }
                    FieldBox(icon: "envelope.fill") {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: .email).submitLabel(.next).onSubmit { focus = .password }
                    }
                    FieldBox(icon: "lock.fill") {
                        HStack {
                            Group {
                                if showPassword { TextField("Password", text: $password) }
                                else { SecureField(mode == .signup ? "Password (8+ characters)" : "Password", text: $password) }
                            }
                            .textContentType(mode == .signup ? .newPassword : .password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: .password).submitLabel(.go).onSubmit { Task { await submit() } }
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill").foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                        }
                    }
                }
                .appear(delay: 0.1)

                if mode == .signup {
                    HStack(spacing: 8) {
                        requirement("2+ letter name", name.trimmingCharacters(in: .whitespaces).count >= 2)
                        requirement("Valid email", emailOK)
                        requirement("8+ characters", password.count >= 8)
                    }
                }

                if let error {
                    HStack(spacing: 10) {
                        LineBadge(icon: "exclamationmark", color: Theme.Colors.red, size: 28)
                        Text(error).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.text)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.35), value: error)
        .sensoryFeedback(.error, trigger: error)
    }

    private func requirement(_ text: String, _ met: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle").foregroundStyle(met ? Theme.Colors.green : Theme.Colors.textSecondary)
            Text(text)
        }
        .font(Theme.Fonts.micro)
        .foregroundStyle(met ? Theme.Colors.text : Theme.Colors.textSecondary)
        .animation(.spring(response: 0.3), value: met)
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .login ? "New here?" : "Have an account?").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                Button(mode == .login ? "Create account" : "Sign in") { switchTo(mode == .login ? .signup : .login) }
                    .font(Theme.Fonts.bold(16)).foregroundStyle(Theme.Colors.text)
                #if DEBUG
                if mode == .login {
                    Button("Use demo account") { email = "demo@gios.app"; password = "campus123" }
                        .font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.yellow)
                }
                #endif
            }
            Spacer()
            Button { Task { await submit() } } label: {
                ZStack {
                    Circle().fill(isValid ? Theme.Colors.yellow : Theme.Colors.surface2).frame(width: 72, height: 72)
                    if isWorking { ProgressView().tint(Theme.Colors.ink) }
                    else { Image(systemName: "arrow.right").font(.system(size: 26, weight: .heavy)).foregroundStyle(isValid ? Theme.Colors.ink : Theme.Colors.textSecondary) }
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(!isValid || isWorking)
            .accessibilityLabel(mode == .login ? "Sign in" : "Create account")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Colors.background)
    }

    private func submit() async {
        guard isValid, !isWorking else { return }
        focus = nil
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
