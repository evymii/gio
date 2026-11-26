import SwiftUI

/// Design tokens. Dark-first, bold, colorful — transit-signage inspired.
enum Theme {
    enum Colors {
        // Base
        static let background = Color(hex: 0x000000)
        static let surface = Color(hex: 0x161618)
        static let surface2 = Color(hex: 0x232326)
        static let line = Color.white.opacity(0.14)
        static let text = Color.white
        static let textSecondary = Color(hex: 0x8D8D93)
        static let paper = Color(hex: 0xF2F1EE)   // light cards (spot sheet)
        static let ink = Color(hex: 0x0B0B0C)     // text on bright colors

        // Signal palette
        static let yellow = Color(hex: 0xFFD60A)
        static let lavender = Color(hex: 0xB4A7FF)
        static let pink = Color(hex: 0xFF4FA3)
        static let green = Color(hex: 0x1DB954)
        static let orange = Color(hex: 0xFF6B1A)
        static let red = Color(hex: 0xE8352B)
        static let blue = Color(hex: 0x1E6BFF)
        static let teal = Color(hex: 0x2EC4B6)
        static let beige = Color(hex: 0xD8CDBD)
        static let lime = Color(hex: 0xC7F25A)
        static let sky = Color(hex: 0x9CCBFF)
        static let coral = Color(hex: 0xFF6F61)

        static let accent = yellow
        static let xp = yellow
        static let online = green
        static let danger = red

        /// Rotation for lists of people / cards.
        static let cycle: [Color] = [lavender, beige, orange, yellow, teal, pink, lime, sky, coral]
        static func cycled(_ i: Int) -> Color { cycle[((i % cycle.count) + cycle.count) % cycle.count] }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 30
        static let control: CGFloat = 20
    }

    enum Fonts {
        /// Heavy grotesk display (titles). Pair with `.tracking(-1)`.
        static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy) }
        static func bold(_ size: CGFloat) -> Font { .system(size: size, weight: .bold) }
        static func medium(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
        static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight).monospacedDigit() }
        static let headline = Font.system(size: 17, weight: .bold)
        static let body = Font.system(size: 16, weight: .medium)
        static let caption = Font.system(size: 13, weight: .medium)
        static let micro = Font.system(size: 11, weight: .semibold)
    }

    /// Icon + color per spot type (pictogram style).
    static func spotStyle(_ type: String) -> (icon: String, color: Color) {
        switch type {
        case "library": ("books.vertical.fill", Colors.lavender)
        case "cafe": ("cup.and.saucer.fill", Colors.orange)
        case "study": ("pencil.and.ruler.fill", Colors.teal)
        case "sports": ("figure.run", Colors.red)
        case "landmark": ("building.columns.fill", Colors.yellow)
        case "food": ("fork.knife", Colors.lime)
        case "event": ("sparkles", Colors.pink)
        default: ("mappin", Colors.sky)
        }
    }

    /// Bright colors take dark text; deep ones take white.
    static func foreground(on color: Color) -> Color {
        [Colors.red, Colors.blue, Colors.green, Colors.surface, Colors.surface2, Colors.background, Colors.ink].contains(color) ? .white : Colors.ink
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

/// Splits a distance into a big number + unit for display cards.
func distanceParts(_ meters: Double?) -> (value: String, unit: String) {
    guard let m = meters else { return ("–", "") }
    return m < 1000 ? ("\(Int(m.rounded()))", "m") : (String(format: "%.1f", m / 1000), "km")
}
