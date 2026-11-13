import SwiftUI

/// Change your name and avatar (free avatars + any you've unlocked).
struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var avatar = ""
    @State private var unlocked: [String] = []
    @State private var saving = false
    @State private var error: String?

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var changed: Bool {
        guard let me = env.session.me else { return false }
        return trimmed != me.name || avatar != me.avatar
    }
    private var valid: Bool { (2...30).contains(trimmed.count) }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    AvatarView(avatar: avatar, name: trimmed.isEmpty ? "?" : trimmed, size: 96)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section {
                TextField("Name", text: $name).textContentType(.name)
            } header: { Text("Name") } footer: {
                if !valid { Text("2–30 characters").foregroundStyle(Theme.Colors.danger) }
            }
            Section("Avatar") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.m) {
                    ForEach(AvatarView.free + unlocked, id: \.self) { id in
                        Button { avatar = id } label: {
                            AvatarView(avatar: id, name: trimmed.isEmpty ? "?" : trimmed, size: 54)
                                .overlay(Circle().stroke(avatar == id ? Theme.Colors.accent : .clear, lineWidth: 3).padding(-4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(id == avatar ? "\(id), selected" : id)
                    }
                }
                .padding(.vertical, Theme.Spacing.s)
            }
        }
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if saving { ProgressView() } else {
                    Button("Save") { Task { await save() } }.disabled(!changed || !valid)
                }
            }
        }
        .task {
            if let me = env.session.me { name = me.name; avatar = me.avatar }
            let inv = (try? await env.api.inventory()) ?? []
            unlocked = inv.filter { $0.reward.type == "avatar" }.map(\.reward.value)
        }
        .errorAlert("Couldn't save", message: $error)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let me = try await env.api.updateMe(name: trimmed, avatar: avatar)
            env.session.update(me)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
