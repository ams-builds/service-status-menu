import AppKit
import SwiftUI

/// Near-black glass in the dark, soft paper in the light. Fills and lines are the foreground
/// colour at a low opacity, so nesting reads the same in both appearances.
/// Layout language is inspired by Hearth (obileonardo/hearth-macos, MIT); no code is copied.
enum Theme {
    static func adaptive(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }

    static let base = adaptive(dark: NSColor(red: 0.047, green: 0.047, blue: 0.058, alpha: 1),
                               light: NSColor(red: 0.953, green: 0.953, blue: 0.965, alpha: 1))
    static let fg = adaptive(dark: .white, light: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
    static let muted = fg.opacity(0.64)
    static let faint = fg.opacity(0.46)
    static let hairline = fg.opacity(0.09)
    static let fill = fg.opacity(0.045)
    static let hover = fg.opacity(0.07)
    static let plate = adaptive(dark: NSColor(red: 0.105, green: 0.105, blue: 0.125, alpha: 1), light: .white)

    static let good = adaptive(dark: NSColor(red: 0.45, green: 0.88, blue: 0.60, alpha: 1),
                               light: NSColor(red: 0.09, green: 0.47, blue: 0.24, alpha: 1))
    static let warn = adaptive(dark: NSColor(red: 1.0, green: 0.70, blue: 0.36, alpha: 1),
                               light: NSColor(red: 0.70, green: 0.38, blue: 0.02, alpha: 1))
    static let bad = adaptive(dark: NSColor(red: 1.0, green: 0.41, blue: 0.37, alpha: 1),
                              light: NSColor(red: 0.76, green: 0.13, blue: 0.11, alpha: 1))
    static let brand = adaptive(dark: NSColor(red: 0.40, green: 0.68, blue: 1.0, alpha: 1),
                                light: NSColor(red: 0.07, green: 0.30, blue: 0.65, alpha: 1))

    static func signal(_ value: Int?) -> Color {
        guard let value else { return faint }
        return value < 35 ? bad : value < 60 ? warn : good
    }
}

extension View {
    /// A card: faint fill, a hairline edge, and a whisper of top light.
    func card(radius: CGFloat = 16) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            shape.fill(Theme.fill)
                .overlay(shape.fill(LinearGradient(colors: [Theme.fg.opacity(0.04), .clear], startPoint: .top, endPoint: .center)))
                .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}

/// Emoji, not words or symbols, so the UI reads in any language. Every glyph also carries a label for VoiceOver and a hover tooltip.
struct IconPlate: View {
    let glyph: String
    var label = ""
    var size: CGFloat = 36

    var body: some View {
        Text(glyph)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .accessibilityLabel(label)
            .help(label)
            .background {
                let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                shape.fill(Theme.plate).overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
            }
    }
}

struct IconButton: View {
    let glyph: String
    let help: String
    var active = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
                .background(Circle().fill(active ? Theme.hover : hovering ? Theme.fill : .clear))
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: active || hovering ? 1 : 0))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(help)
        .help(help)
    }
}

