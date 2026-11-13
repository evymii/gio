import SwiftUI

/// Design tokens — screens use these, never raw values, so the final visual
/// design can be applied in one place. System colors keep dark mode working.
enum Theme {
    enum Colors {
        static let accent = Color(hex: 0x2E8B7A)        // campus green
        static let accentSoft = Color(hex: 0x2E8B7A).opacity(0.14)
        static let xp = Color(hex: 0xF2A93B)            // XP / rewards gold
        static let online = Color(hex: 0x34C759)
        static let danger = Color(hex: 0xE5484D)
        static let background = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let text = Color.primary
        static let textSecondary = Color.secondary
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 18
        static let control: CGFloat = 12
    }

    enum Fonts {
        static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
        static let title = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let number = Font.system(.title3, design: .rounded).weight(.bold).monospacedDigit()
    }

    /// Icon + color per spot type.
    static func spotStyle(_ type: String) -> (icon: String, color: Color) {
        switch type {
        case "library": ("books.vertical.fill", Color(hex: 0x5B6CFF))
        case "cafe": ("cup.and.saucer.fill", Color(hex: 0xA0673A))
        case "study": ("pencil.and.ruler.fill", Color(hex: 0x2E8B7A))
        case "sports": ("figure.run", Color(hex: 0xE5484D))
        case "landmark": ("building.columns.fill", Color(hex: 0x8E6CEF))
        case "food": ("fork.knife", Color(hex: 0xF2A93B))
        case "event": ("sparkles", Color(hex: 0xE5488F))
        default: ("mappin", Color(hex: 0x2E8B7A))
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

/// "350 m" / "1.2 km"
func formatDistance(_ meters: Double?) -> String {
    guard let m = meters else { return "" }
    return m < 1000 ? "\(Int(m.rounded())) m" : String(format: "%.1f km", m / 1000)
}
