import SwiftUI

/// Brand moment while the session is restored. Replace visuals with the final design.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.Colors.accent, Color(hex: 0x1F5F54)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: Theme.Spacing.m) {
                ZStack {
                    Circle().fill(.white.opacity(0.15)).frame(width: 120, height: 120)
                        .scaleEffect(appeared ? 1.15 : 0.8)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Gios").font(Theme.Fonts.display(44)).foregroundStyle(.white)
                Text("your campus, together").font(Theme.Fonts.body).foregroundStyle(.white.opacity(0.8))
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }
}

#Preview { SplashView() }
