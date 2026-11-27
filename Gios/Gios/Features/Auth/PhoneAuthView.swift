import SwiftUI

/// Phone sign-in: number → SMS code. Same screen for new and returning players.
struct PhoneAuthView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var phone = ""
    @State private var code = ""
    @State private var verificationID: String?
    @State private var isWorking = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var digits: String { phone.filter(\.isNumber) }
    private var phoneOK: Bool { (8...15).contains(digits.count) }
    private var codeOK: Bool { code.filter(\.isNumber).count == 6 }
    private var onCodeStep: Bool { verificationID != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                HStack(spacing: 10) {
                    LineBadge(icon: onCodeStep ? "number" : "phone.fill", color: Theme.Colors.yellow, size: 52)
                    ArrowBadge(systemName: "arrow.up.right", color: Theme.Colors.lavender, foreground: Theme.Colors.ink, size: 52)
                }
                .appear()
                StackedTitle(primary: onCodeStep ? "Enter the" : "Your phone",
                             secondary: onCodeStep ? "Code" : "Number", size: 52)
                    .appear(delay: 0.05)

                if onCodeStep { codeStep } else { phoneStep }

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
        .animation(.spring(response: 0.4), value: onCodeStep)
        .sensoryFeedback(.error, trigger: error)
        .onAppear { focused = true }
    }

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldBox(icon: "phone.fill") {
                HStack(spacing: 8) {
                    Text(PhoneAuth.defaultCountryCode).font(Theme.Fonts.bold(17)).foregroundStyle(Theme.Colors.textSecondary)
                    TextField("9911 2233", text: $phone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .focused($focused)
                }
            }
            Text("We'll text you a 6-digit code.").font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.textSecondary)
            #if DEBUG
            Button("Use test number (no SMS)") { phone = "99999999" }
                .font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.yellow)
            #endif
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldBox(icon: "number") {
                TextField("123456", text: $code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .font(Theme.Fonts.number(28, weight: .regular)).tracking(6)
                    .focused($focused)
                    .onChange(of: code) { _, new in
                        code = String(new.filter(\.isNumber).prefix(6))
                        if codeOK { Task { await submit() } }
                    }
            }
            HStack {
                Text("Sent to \(PhoneAuth.e164(phone))").font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Button("Change number") { verificationID = nil; code = ""; error = nil }
                    .font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.yellow)
            }
            #if DEBUG
            Button("Fill test code") { code = "123456" }
                .font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.yellow)
            #endif
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var bottomBar: some View {
        HStack {
            if onCodeStep {
                Button("Resend code") { Task { await sendCode() } }
                    .font(Theme.Fonts.bold(16)).foregroundStyle(Theme.Colors.text)
                    .disabled(isWorking)
            }
            Spacer()
            let ready = onCodeStep ? codeOK : phoneOK
            Button { Task { await submit() } } label: {
                ZStack {
                    Circle().fill(ready ? Theme.Colors.yellow : Theme.Colors.surface2).frame(width: 72, height: 72)
                    if isWorking { ProgressView().tint(Theme.Colors.ink) }
                    else { Image(systemName: "arrow.right").font(.system(size: 26, weight: .heavy)).foregroundStyle(ready ? Theme.Colors.ink : Theme.Colors.textSecondary) }
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(!ready || isWorking)
            .accessibilityLabel(onCodeStep ? "Confirm code" : "Send code")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Colors.background)
    }

    private func submit() async {
        if onCodeStep { await confirm() } else { await sendCode() }
    }

    private func sendCode() async {
        guard phoneOK, !isWorking else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            verificationID = try await PhoneAuth.sendCode(to: PhoneAuth.e164(phone))
            code = ""
            focused = true
        } catch {
            self.error = PhoneAuth.message(for: error)
        }
    }

    private func confirm() async {
        guard let verificationID, codeOK, !isWorking else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let idToken = try await PhoneAuth.confirm(verificationID: verificationID, code: code)
            try await env.session.loginWithFirebase(idToken: idToken)
        } catch {
            self.error = PhoneAuth.message(for: error)
            code = ""
        }
    }
}
