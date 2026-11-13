import SwiftUI

// MARK: - Typography

/// Two-tone stacked title: first line white, second line gray. ("Hi Demo / North Campus")
struct StackedTitle: View {
    let primary: String
    var secondary: String? = nil
    var size: CGFloat = 34
    var primaryColor: Color = Theme.Colors.text
    var secondaryColor: Color = Theme.Colors.textSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.12) {
            Text(primary).foregroundStyle(primaryColor)
            if let secondary { Text(secondary).foregroundStyle(secondaryColor) }
        }
        .font(Theme.Fonts.display(size))
        .tracking(-size * 0.03)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }
}

/// Big number + small unit ("160 XP", "7 Days").
struct BigStat: View {
    let value: String
    let unit: String
    var size: CGFloat = 64
    var color: Color = Theme.Colors.text
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value).font(Theme.Fonts.number(size, weight: .medium)).tracking(-size * 0.04).foregroundStyle(color)
            Text(unit).font(Theme.Fonts.medium(15)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Badges

/// Round transit-line badge with a letter, number or SF Symbol.
struct LineBadge: View {
    enum Content { case text(String), icon(String) }
    let content: Content
    var color: Color
    var size: CGFloat = 44
    var foreground: Color? = nil

    init(_ text: String, color: Color, size: CGFloat = 44) {
        content = .text(text); self.color = color; self.size = size
    }
    init(icon: String, color: Color, size: CGFloat = 44, foreground: Color? = nil) {
        content = .icon(icon); self.color = color; self.size = size; self.foreground = foreground
    }

    var body: some View {
        Circle().fill(color)
            .frame(width: size, height: size)
            .overlay {
                switch content {
                case let .text(t):
                    Text(t).font(.system(size: size * (t.count > 2 ? 0.34 : 0.48), weight: .heavy))
                        .minimumScaleFactor(0.5).lineLimit(1).padding(size * 0.08)
                case let .icon(name):
                    Image(systemName: name).font(.system(size: size * 0.42, weight: .bold))
                }
            }
            .foregroundStyle(foreground ?? Theme.foreground(on: color))
            .accessibilityHidden(true)
    }
}

/// Circle with an arrow (↗ ↘ →) — "go" affordance on cards.
struct ArrowBadge: View {
    var systemName = "arrow.up.right"
    var color: Color = Theme.Colors.ink.opacity(0.08)
    var foreground: Color = Theme.Colors.ink
    var size: CGFloat = 40
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .overlay(Circle().strokeBorder(foreground.opacity(0.15), lineWidth: 1))
            .overlay(Image(systemName: systemName).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(foreground))
            .accessibilityHidden(true)
    }
}

/// Person avatar as a line badge: color from avatar id, initial (or special glyph).
struct AvatarView: View {
    let avatar: String
    let name: String
    var size: CGFloat = 44
    var online: Bool? = nil

    static let palette: [Color] = [Theme.Colors.lavender, Theme.Colors.teal, Theme.Colors.pink, Theme.Colors.yellow,
                                   Theme.Colors.orange, Theme.Colors.sky, Theme.Colors.lime, Theme.Colors.beige]
    static let special: [String: (symbol: String, color: Color)] = [
        "avatar-cafe": ("cup.and.saucer.fill", Theme.Colors.orange),
    ]
    static let free = (1...8).map { "avatar-\($0)" }

    var color: Color {
        if let s = Self.special[avatar] { return s.color }
        let n = Int(avatar.split(separator: "-").last ?? "") ?? avatar.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.palette[(max(n, 1) - 1) % Self.palette.count]
    }

    var body: some View {
        Group {
            if let s = Self.special[avatar] { LineBadge(icon: s.symbol, color: s.color, size: size) }
            else { LineBadge(String(name.prefix(1)).uppercased(), color: color, size: size) }
        }
        .overlay(alignment: .bottomTrailing) {
            if let online {
                Circle().fill(online ? Theme.Colors.green : Theme.Colors.textSecondary)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 3))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Spot pictogram: rounded square tile with a glyph (signage style).
struct SpotIcon: View {
    let type: String
    var size: CGFloat = 44
    var body: some View {
        let s = Theme.spotStyle(type)
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(s.color)
            .frame(width: size, height: size)
            .overlay(Image(systemName: s.icon).font(.system(size: size * 0.46, weight: .bold)).foregroundStyle(Theme.foreground(on: s.color)))
            .accessibilityHidden(true)
    }
}

/// Small capsule tag.
struct Tag: View {
    let text: String
    var tint: Color = Theme.Colors.yellow
    var filled = false
    var body: some View {
        Text(text).font(Theme.Fonts.micro)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(filled ? Theme.foreground(on: tint) : tint)
            .background(filled ? tint : tint.opacity(0.16), in: Capsule())
    }
}

// MARK: - Cards

/// Colorful stacked card: badge + arrow on top, bold title + subtitle, big number on the right.
struct StackCard<Badge: View>: View {
    let color: Color
    let title: String
    var subtitle: String = ""
    var value: String = ""
    var unit: String = ""
    var arrow = "arrow.up.right"
    @ViewBuilder var badge: Badge

    var body: some View {
        let fg = Theme.foreground(on: color)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                badge
                Spacer()
                ArrowBadge(systemName: arrow, color: fg.opacity(0.06), foreground: fg)
            }
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.Fonts.display(26)).tracking(-0.8).lineLimit(2).minimumScaleFactor(0.8)
                    if !subtitle.isEmpty { Text(subtitle).font(Theme.Fonts.caption).opacity(0.6) }
                }
                Spacer(minLength: 8)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value).font(Theme.Fonts.number(52, weight: .regular)).tracking(-2)
                    if !unit.isEmpty { Text(unit).font(Theme.Fonts.bold(15)).opacity(0.6) }
                }
                .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(fg)
        .padding(20)
        .padding(.bottom, 26) // room for the next card to overlap
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

/// Overlapping stack of cards (later cards sit on top).
struct CardStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    @ViewBuilder var content: (Int, Data.Element) -> Content
    var body: some View {
        VStack(spacing: -28) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                content(i, item)
                    .zIndex(Double(i))
                    .appear(delay: Double(i) * 0.06)
            }
        }
    }
}

/// Big capsule row (habit style): filled when done/ready, outlined while in progress, struck through when finished.
struct PillRow: View {
    let title: String
    let value: String
    var color: Color
    var filled = true
    var struck = false

    var body: some View {
        let fg = filled ? Theme.foreground(on: color) : Theme.Colors.text
        HStack {
            Text(title).font(Theme.Fonts.display(28)).tracking(-1).strikethrough(struck, color: fg)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            Text(value).font(Theme.Fonts.number(24, weight: .regular))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 26)
        .frame(height: 78)
        .background {
            if filled { Capsule().fill(color) }
            else { Capsule().strokeBorder(Theme.Colors.line, lineWidth: 1.5).background(Capsule().fill(Theme.Colors.surface)) }
        }
    }
}

/// Dark rounded container.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    var color: Color = Theme.Colors.surface
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

/// Section header: bold title + optional trailing link.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .bottom) {
            StackedTitle(primary: title, secondary: subtitle, size: 22)
            Spacer()
            trailing.font(Theme.Fonts.bold(14)).foregroundStyle(Theme.Colors.yellow)
        }
        .padding(.horizontal, 4)
    }
}
extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) { self.title = title; self.subtitle = subtitle; self.trailing = EmptyView() }
}

// MARK: - Controls

/// Round icon button (outlined on dark, or filled).
struct CircleButton: View {
    let systemName: String
    var size: CGFloat = 56
    var fill: Color? = nil
    var foreground: Color? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .bold))
                .frame(width: size, height: size)
                .foregroundStyle(foreground ?? (fill.map(Theme.foreground(on:)) ?? Theme.Colors.text))
                .background {
                    if let fill { Circle().fill(fill) }
                    else { Circle().strokeBorder(Theme.Colors.line, lineWidth: 1.5) }
                }
        }
        .buttonStyle(PressableStyle())
    }
}

/// Big capsule button.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Theme.Colors.yellow
    var outlined = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.bold(18))
            .foregroundStyle(outlined ? Theme.Colors.text : Theme.foreground(on: fill))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background {
                if outlined { Capsule().strokeBorder(Theme.Colors.line, lineWidth: 1.5) }
                else { Capsule().fill(fill) }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
typealias PrimaryButtonStyle = PillButtonStyle

/// Subtle press-down for any tappable card.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Filter chip (selected = white capsule).
struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Theme.Fonts.bold(16))
                .padding(.horizontal, 18).padding(.vertical, 11)
                .foregroundStyle(selected ? Theme.Colors.ink : Theme.Colors.text)
                .background(selected ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(response: 0.3), value: selected)
    }
}

/// Dark rounded text field with an icon.
struct FieldBox<Field: View>: View {
    let icon: String
    @ViewBuilder var field: Field
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.Colors.textSecondary).frame(width: 24)
            field.font(Theme.Fonts.medium(18)).foregroundStyle(Theme.Colors.text)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}

// MARK: - Data visualisation

/// N-segment progress bar (first k segments lit).
struct SegmentBar: View {
    let fraction: Double
    var segments = 4
    var color: Color = Theme.Colors.orange
    var track: Color = Theme.Colors.ink.opacity(0.08)
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<segments, id: \.self) { i in
                let lit = fraction >= Double(i + 1) / Double(segments) - 0.0001 || (i == 0 && fraction > 0)
                Capsule().fill(lit ? color : track).frame(height: 6)
            }
        }
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

/// Rounded progress bar.
struct ProgressBar: View {
    let value: Double
    var tint: Color = Theme.Colors.yellow
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.surface2)
                Capsule().fill(tint).frame(width: max(height, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// Concentric "transit line" arcs — one colored track per metric, with a stop marker at its value.
struct TrackArc: View {
    struct Track: Identifiable { let id: String; let fraction: Double; let color: Color }
    let tracks: [Track]
    var width: CGFloat = 16
    @State private var progress: Double = 0

    var body: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width / 2, geo.size.height) - 2
            ZStack {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { i, t in
                    let r = outer - CGFloat(i) * width - width / 2
                    ArcShape(radius: r, fraction: 1).stroke(t.color.opacity(0.22), style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    ArcShape(radius: r, fraction: t.fraction * progress).stroke(t.color, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    StopMarker(radius: r, fraction: t.fraction * progress, size: width * 0.62)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .onAppear { withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.15)) { progress = 1 } }
        .accessibilityHidden(true)
    }

    private struct ArcShape: Shape {
        let radius: CGFloat
        var fraction: Double
        var animatableData: Double { get { fraction } set { fraction = newValue } }
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let c = CGPoint(x: rect.midX, y: rect.maxY)
            p.addArc(center: c, radius: radius, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * min(1, max(0, fraction))), clockwise: false)
            return p
        }
    }

    private struct StopMarker: View {
        let radius: CGFloat
        let fraction: Double
        let size: CGFloat
        var body: some View {
            GeometryReader { geo in
                let a = Angle.degrees(180 + 180 * min(1, max(0, fraction))).radians
                Circle().fill(Theme.Colors.ink)
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
                    .frame(width: size, height: size)
                    .position(x: geo.size.width / 2 + radius * cos(a), y: geo.size.height + radius * sin(a))
            }
        }
    }
}

/// Month grid of circles; days in `filled` are lit with a count.
struct DotCalendar: View {
    let month: Date
    let counts: [Date: Int] // keyed by start of day
    var color: Color = Theme.Colors.pink

    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; return c }

    var body: some View {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let days = cal.range(of: .day, in: .month, for: start)!.count
        let lead = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        let today = cal.startOfDay(for: .now)
        VStack(spacing: 10) {
            Text(start.formatted(.dateTime.month(.wide))).font(Theme.Fonts.bold(20))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.textSecondary)
                }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(1...days, id: \.self) { d in
                    let date = cal.date(byAdding: .day, value: d - 1, to: start)!
                    let n = counts[date] ?? 0
                    ZStack {
                        if n > 0 { Circle().fill(color) }
                        else { Circle().strokeBorder(date == today ? Theme.Colors.text : Theme.Colors.line, lineWidth: date == today ? 2 : 1.2) }
                        Text("\(d)").font(Theme.Fonts.bold(14))
                            .foregroundStyle(n > 0 ? Theme.foreground(on: color) : (date > today ? Theme.Colors.textSecondary.opacity(0.5) : Theme.Colors.text))
                    }
                    .frame(height: 40)
                    .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(n) check-ins")
                }
            }
        }
    }
}

// MARK: - Motion

extension View {
    /// Fade + rise in when first shown (staggered with `delay`).
    func appear(delay: Double = 0) -> some View { modifier(AppearModifier(delay: delay)) }

    /// Scale/fade cards as they scroll in and out of view.
    func scrollFade() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.94).opacity(phase.isIdentity ? 1 : 0.5)
        }
    }

    func errorAlert(_ title: String = "Something went wrong", message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message.wrappedValue ?? "") }
    }

    /// Standard dark page chrome.
    func pageBackground() -> some View {
        background(Theme.Colors.background.ignoresSafeArea())
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
    }
}

private struct AppearModifier: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 24)
            .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) { shown = true } }
    }
}

// MARK: - Folder tiles

/// Rounded card with a folder tab on the top-left.
struct FolderShape: Shape {
    var tabWidth: CGFloat = 0.5
    var tabHeight: CGFloat = 22
    var radius: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        let r = radius, th = tabHeight, tw = rect.width * tabWidth
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: tw - r * 0.6, y: rect.minY))
        p.addCurve(to: CGPoint(x: tw + r * 0.9, y: rect.minY + th),
                   control1: CGPoint(x: tw + r * 0.1, y: rect.minY), control2: CGPoint(x: tw + r * 0.2, y: rect.minY + th))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY + th))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + th + r), control: CGPoint(x: rect.maxX, y: rect.minY + th))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Stat in a folder-tab tile: black icon circle, big value, label.
struct FolderStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LineBadge(icon: icon, color: Theme.Colors.ink, size: 46, foreground: color)
            Spacer(minLength: 0)
            Text(value).font(Theme.Fonts.number(34, weight: .bold)).tracking(-1)
            Text(label).font(Theme.Fonts.caption).opacity(0.65)
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(color, in: FolderShape())
        .accessibilityElement(children: .combine)
    }
}

/// Square-ish quick action tile with a ↗ circle.
struct ActionTile: View {
    let title: String
    var color: Color = .white
    var body: some View {
        VStack(alignment: .leading) {
            ArrowBadge(color: Theme.foreground(on: color).opacity(0.07), foreground: Theme.foreground(on: color), size: 40)
            Spacer(minLength: 24)
            Text(title).font(Theme.Fonts.bold(18)).multilineTextAlignment(.leading)
        }
        .foregroundStyle(Theme.foreground(on: color))
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Sentence where some words are highlighted ("Today you're at **North Campus**").
struct HighlightSentence: View {
    let parts: [(String, Bool)]
    var size: CGFloat = 26
    var body: some View {
        parts.reduce(Text("")) { acc, part in
            acc + Text(part.0).foregroundColor(part.1 ? Theme.Colors.text : Theme.Colors.textSecondary)
        }
        .font(.system(size: size, weight: .semibold))
        .tracking(-0.5)
        .lineSpacing(2)
    }
}
