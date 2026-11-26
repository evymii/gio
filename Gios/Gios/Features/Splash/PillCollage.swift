import SwiftUI

/// Scattered, rotated colorful pills with campus words — the brand moment.
struct PillCollage: View {
    struct Pill: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
        let x: CGFloat, y: CGFloat      // centre, as a fraction of the area
        let w: CGFloat                  // width as a fraction of the area width
        let angle: Double
    }

    static let pills: [Pill] = [
        .init(text: "Library", color: Theme.Colors.lavender, x: 0.22, y: 0.16, w: 0.62, angle: 62),
        .init(text: "Check in", color: Theme.Colors.orange, x: 0.78, y: 0.12, w: 0.66, angle: -58),
        .init(text: "Friends", color: Theme.Colors.green, x: 0.2, y: 0.42, w: 0.66, angle: 55),
        .init(text: "Quests", color: Theme.Colors.pink, x: 0.66, y: 0.36, w: 0.6, angle: 18),
        .init(text: "Café", color: Theme.Colors.teal, x: 0.52, y: 0.22, w: 0.5, angle: -32),
        .init(text: "Explore", color: Theme.Colors.blue, x: 0.74, y: 0.62, w: 0.72, angle: 38),
        .init(text: "Level up", color: Theme.Colors.lime, x: 0.46, y: 0.76, w: 0.7, angle: -60),
        .init(text: "Map", color: Theme.Colors.coral, x: 0.36, y: 0.56, w: 0.5, angle: 92),
        .init(text: "Gym", color: Theme.Colors.yellow, x: 0.1, y: 0.8, w: 0.5, angle: 70),
    ]

    var animated = true
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(Self.pills.enumerated()), id: \.element.id) { i, p in
                    Capsule()
                        .fill(p.color)
                        .frame(width: geo.size.width * p.w, height: geo.size.width * 0.27)
                        .overlay(
                            Text(p.text).font(Theme.Fonts.display(geo.size.width * 0.105)).tracking(-1)
                                .foregroundStyle(Theme.foreground(on: p.color))
                                .lineLimit(1).minimumScaleFactor(0.5).padding(.horizontal, 24)
                        )
                        .rotationEffect(.degrees(shown ? p.angle : p.angle + 40))
                        .scaleEffect(shown ? 1 : 0.3)
                        .opacity(shown ? 1 : 0)
                        .position(x: geo.size.width * p.x, y: geo.size.height * p.y + (shown ? 0 : -80))
                        .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(Double(i) * 0.06), value: shown)
                }
            }
        }
        .clipped()
        .onAppear { if animated { shown = true } else { var t = Transaction(); t.disablesAnimations = true; withTransaction(t) { shown = true } } }
        .accessibilityHidden(true)
    }
}

/// Splash: collage + wordmark while the session restores.
struct SplashView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.Colors.background.ignoresSafeArea()
            PillCollage().ignoresSafeArea()
            StackedTitle(primary: "Gios", secondary: "your campus, live", size: 56)
                .padding(Theme.Spacing.l)
                .padding(.bottom, 24)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.9), .black], startPoint: .top, endPoint: .bottom).padding(.top, -80))
        }
    }
}

#Preview { SplashView() }
