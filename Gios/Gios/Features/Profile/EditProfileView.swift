import SwiftUI

/// Change your name and pick an avatar from a grid of badges ("Choose your look").
struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var avatar = ""
    @State private var saving = false
    @State private var error: String?

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var changed: Bool {
        guard let me = env.session.me else { return false }
        return trimmed != me.name || avatar != me.avatar
    }
    private var valid: Bool { (2...30).contains(trimmed.count) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                StackedTitle(primary: "Choose", secondary: "Your Look", size: 44).appear()
                HStack {
                    Spacer()
                    AvatarView(avatar: avatar, name: trimmed.isEmpty ? "?" : trimmed, size: 120)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: avatar)
                    Spacer()
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(AvatarView.free, id: \.self) { id in
                        Button { avatar = id } label: {
                            AvatarView(avatar: id, name: trimmed.isEmpty ? "?" : trimmed, size: 70)
                                .overlay(Circle().strokeBorder(.white, lineWidth: avatar == id ? 4 : 0).padding(-6))
                                .scaleEffect(avatar == id ? 0.9 : 1)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(avatar == id ? "\(id), selected" : id)
                    }
                }
                .animation(.spring(response: 0.3), value: avatar)
                .sensoryFeedback(.selection, trigger: avatar)

                VStack(alignment: .leading, spacing: 8) {
                    FieldBox(icon: "person.fill") { TextField("Name", text: $name).textContentType(.name) }
                    if !valid { Text("2–30 characters").font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.red) }
                }
                Button { Task { await save() } } label: {
                    if saving { ProgressView().tint(Theme.Colors.ink) } else { Text("Save") }
                }
                .buttonStyle(PillButtonStyle())
                .disabled(!changed || !valid || saving)
            }
            .padding(Theme.Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let me = env.session.me { name = me.name; avatar = me.avatar }
        }
        .errorAlert("Couldn't save", message: $error)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            env.session.update(try await env.api.updateMe(name: trimmed, avatar: avatar))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
