import SwiftUI

/// Rounded card container.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.m
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s + 4) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// Section title with an optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Text(title).font(Theme.Fonts.headline)
            Spacer()
            trailing.font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}
extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.title = title; self.trailing = EmptyView() }
}

/// Avatar: colored circle with the user's initial, or a special unlocked avatar.
struct AvatarView: View {
    let avatar: String
    let name: String
    var size: CGFloat = 40
    var online: Bool? = nil

    static let palette: [UInt32] = [0x5B6CFF, 0x2E8B7A, 0xE5488F, 0xF2A93B, 0x8E6CEF, 0xE5484D, 0x3BA7F2, 0xA0673A]
    /// Avatars unlocked through rewards (value → symbol + color).
    static let special: [String: (symbol: String, color: UInt32)] = [
        "avatar-cafe": ("cup.and.saucer.fill", 0xA0673A),
    ]
    static let free = (1...8).map { "avatar-\($0)" }

    private var style: (color: Color, symbol: String?) {
        if let s = Self.special[avatar] { return (Color(hex: s.color), s.symbol) }
        // Stable across launches (unlike hashValue): "avatar-3" → index 2.
        let n = Int(avatar.split(separator: "-").last ?? "") ?? avatar.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (Color(hex: Self.palette[(max(n, 1) - 1) % Self.palette.count]), nil)
    }

    var body: some View {
        let s = style
        Circle()
            .fill(s.color.gradient)
            .frame(width: size, height: size)
            .overlay {
                if let symbol = s.symbol {
                    Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white)
                } else {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let online {
                    Circle().fill(online ? Theme.Colors.online : Color.gray)
                        .frame(width: size * 0.28, height: size * 0.28)
                        .overlay(Circle().stroke(Theme.Colors.surface, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
    }
}

/// Small rounded tag (reward type, spot type, status).
struct Tag: View {
    let text: String
    var tint: Color = Theme.Colors.accent
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

/// Shared error alert binding.
extension View {
    func errorAlert(_ title: String = "Something went wrong", message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message.wrappedValue ?? "") }
    }
}

/// Thin rounded progress bar.
struct ProgressBar: View {
    let value: Double
    var tint: Color = Theme.Colors.accent
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule().fill(tint).frame(width: max(height, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// Spot-type badge.
struct SpotIcon: View {
    let type: String
    var size: CGFloat = 36
    var body: some View {
        let style = Theme.spotStyle(type)
        RoundedRectangle(cornerRadius: size * 0.3)
            .fill(style.color.gradient)
            .frame(width: size, height: size)
            .overlay(Image(systemName: style.icon).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white))
            .accessibilityHidden(true)
    }
}

/// Primary filled button style.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.Colors.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
