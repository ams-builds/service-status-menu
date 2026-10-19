import AppKit
import SwiftUI

// The look of Hearth (https://github.com/obileonardo/hearth-macos): colours, cards, glass, the dock
// and the title that pins to the top as you scroll. Adapted from Hearth's source under its MIT licence:
//
// Copyright (c) 2026 Elvis Obi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// This same file is used by Service Status and the Orbi menu, so all three apps share one look.
// Change it in one, copy it to the other.

enum Theme {
    static let panel = CGSize(width: 448, height: 696)

    static func adaptive(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }
    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: 1)
    }

    static let base = adaptive(dark: rgb(0.027, 0.027, 0.034), light: rgb(0.957, 0.957, 0.965))
    static let fg = adaptive(dark: .white, light: rgb(0.07, 0.07, 0.09))
    static let ink = adaptive(dark: .white.withAlphaComponent(0.95), light: rgb(0.07, 0.07, 0.09))
    static let muted = adaptive(dark: .white.withAlphaComponent(0.68), light: rgb(0.33, 0.33, 0.36))
    static let faint = adaptive(dark: .white.withAlphaComponent(0.5), light: rgb(0.42, 0.42, 0.45))
    static let hairline = adaptive(dark: .white.withAlphaComponent(0.075), light: .black.withAlphaComponent(0.1))
    static let cardEdge = adaptive(dark: .white.withAlphaComponent(0.1), light: .black.withAlphaComponent(0.075))
    static let hover = adaptive(dark: .white.withAlphaComponent(0.05), light: .black.withAlphaComponent(0.04))
    static let fill = fg.opacity(0.06)
    /// The opaque plate behind an icon.
    static let plate = adaptive(dark: rgb(0.1, 0.1, 0.115), light: .white)
    static let field = adaptive(dark: .black.withAlphaComponent(0.32), light: .white)
    static let fieldEdge = adaptive(dark: .white.withAlphaComponent(0.16), light: .black.withAlphaComponent(0.44))

    static let good = adaptive(dark: rgb(0.5, 0.9, 0.62), light: rgb(0.09, 0.47, 0.24))
    static let warn = adaptive(dark: rgb(1.0, 0.70, 0.36), light: rgb(0.70, 0.38, 0.02))
    static let bad = adaptive(dark: rgb(1.0, 0.36, 0.32), light: rgb(0.78, 0.13, 0.11))
    static let brand = adaptive(dark: rgb(0.26, 0.61, 0.99), light: rgb(0.07, 0.30, 0.65))

    static func signal(_ value: Int?) -> Color {
        guard let value else { return faint }
        return value < 35 ? bad : value < 60 ? warn : good
    }
}

// MARK: Panel

/// The panel behind everything: near-black with a soft light from the top and a fine film grain.
struct PanelBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let light = scheme == .light
        ZStack {
            Theme.base
            LinearGradient(colors: [light ? Color.white.opacity(0.55) : Theme.fg.opacity(0.035), .clear],
                           startPoint: .top, endPoint: .center)
            Image(nsImage: Grain.image)
                .resizable(resizingMode: .tile)
                .opacity(light ? 0.025 : 0.05)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

@MainActor
enum Grain {
    static let image: NSImage = {
        let size = 160
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                   samplesPerPixel: 2, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceWhite, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<size {
            for x in 0..<size {
                var pixel = [Int.random(in: 0...255), Int.random(in: 0...60)]
                rep.setPixel(&pixel, atX: x, y: y)
            }
        }
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        return image
    }()
}

// MARK: Cards

/// Hearth's card: lit glass in the dark (a soft white wash and a rim caught by light from above),
/// a white card with a fine edge and a soft shadow on paper.
private struct Card: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if scheme == .light {
            content.background {
                shape.fill(Color.white)
                    .overlay(shape.strokeBorder(Theme.cardEdge, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.05), radius: 0.75, y: 0.5)
                    .shadow(color: .black.opacity(0.055), radius: 10, y: 4)
            }
        } else {
            content.background {
                shape.fill(LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [Theme.fg.opacity(0.12), Theme.fg.opacity(0.02)],
                                                               startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
            }
        }
    }
}

extension View {
    func card(radius: CGFloat = 16) -> some View { modifier(Card(radius: radius)) }
}

/// Buttons press in like a physical key and brighten a touch under the pointer.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { PressBody(configuration: configuration) }

    private struct PressBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var hovering = false
        @Environment(\.colorScheme) private var scheme
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .scaleEffect(configuration.isPressed ? 0.965 : 1)
                .brightness(configuration.isPressed ? (scheme == .light ? -0.05 : -0.04)
                            : hovering && enabled ? (scheme == .light ? -0.018 : 0.035) : 0)
                .onHover { hovering = $0 }
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: configuration.isPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: hovering)
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
                .background(Circle().fill(active ? Theme.fill : hovering ? Theme.hover : .clear))
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: active || hovering ? 1 : 0))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(help)
        .help(help)
    }
}

/// A count in the heading: emoji, then the number, never clipped.
struct CountChip: View {
    let glyph: String
    let value: Int
    let label: String
    var color: Color = Theme.ink

    var body: some View {
        HStack(spacing: 4) {
            Text(glyph).font(.system(size: 12))
            Text("\(value)").font(.system(size: 12.5, weight: .semibold)).monospacedDigit().foregroundStyle(color)
        }
        .fixedSize()
        .padding(.horizontal, 10).frame(height: 30)
        .background(Capsule().fill(Theme.fg.opacity(0.06)).overlay(Capsule().strokeBorder(Theme.hairline)))
        .help(label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: Glass

/// Hearth's navigation glass: a dark fill at 55% over clear Liquid Glass, with a lit rim.
/// Only the dock and the pinned title use it; the page scrolls underneath both.
private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    var surfaceOpacity = 0.55
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var rim: LinearGradient {
        LinearGradient(colors: [Theme.fg.opacity(0.24), Theme.fg.opacity(0.06)], startPoint: .top, endPoint: .bottom)
    }

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(shape.fill(Theme.plate))
                .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            content
                .background(shape.fill(Theme.plate.opacity(surfaceOpacity)))
                .glassEffect(.clear, in: shape)
                .overlay(shape.strokeBorder(rim, lineWidth: 0.75))
        } else {
            content
                .background { ZStack { shape.fill(.ultraThinMaterial); shape.fill(Theme.plate.opacity(surfaceOpacity)) } }
                .overlay(shape.strokeBorder(rim, lineWidth: 0.75))
        }
    }
}

extension View {
    func glassBar(radius: CGFloat = 18) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    func glassPill() -> some View {
        modifier(GlassSurface(shape: Capsule()))
    }
}

/// The chosen tab's lens: a bead of clearer glass with light caught on its rim.
private struct Lens: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var rim: LinearGradient {
        LinearGradient(colors: [Theme.fg.opacity(0.22), Theme.fg.opacity(0.03)], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        if reduceTransparency || contrast == .increased {
            Capsule().fill(Theme.plate).overlay(Capsule().strokeBorder(Theme.brand, lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            Capsule().fill(.clear).glassEffect(.clear, in: Capsule()).overlay(Capsule().strokeBorder(rim, lineWidth: 0.75))
        } else {
            Capsule()
                .fill(LinearGradient(colors: [Theme.fg.opacity(0.13), Theme.fg.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().strokeBorder(rim, lineWidth: 0.75))
        }
    }
}

// MARK: Dock

struct DockPage<Page: Hashable> {
    let page: Page
    let glyph: String
    let help: String
}

struct DockAction: Identifiable {
    let glyph: String
    let help: String
    var disabled = false
    /// Turns once when clicked, for refresh.
    var spins = false
    let run: () -> Void
    var id: String { glyph }
}

/// Hearth's dock: a small pill of equal-width emoji tabs, with a lens of glass that slides
/// under the current page, then the actions after a hairline.
struct Dock<Page: Hashable>: View {
    let pages: [DockPage<Page>]
    @Binding var selection: Page
    var actions: [DockAction] = []
    @Namespace private var lens
    @State private var turns = 0.0

    static var tab: CGSize { CGSize(width: 44, height: 34) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(pages.indices, id: \.self) { index in
                let item = pages[index]
                let on = item.page == selection
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.94)) { selection = item.page }
                } label: {
                    Text(item.glyph).font(.system(size: 17))
                        .frame(width: Self.tab.width, height: Self.tab.height)
                        .background { if on { Lens().matchedGeometryEffect(id: "lens", in: lens) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .help(item.help)
                .accessibilityLabel(item.help)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            if !pages.isEmpty && !actions.isEmpty {
                Capsule().fill(Theme.hairline).frame(width: 1, height: 18).frame(width: 9)
            }
            ForEach(actions) { action in
                Button {
                    if action.spins { withAnimation(.easeInOut(duration: 0.6)) { turns += 360 } }
                    action.run()
                } label: {
                    Text(action.glyph).font(.system(size: 17))
                        .rotationEffect(.degrees(action.spins ? turns : 0))
                        .frame(width: Self.tab.width, height: Self.tab.height)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .disabled(action.disabled)
                .opacity(action.disabled ? 0.4 : 1)
                .help(action.help)
                .accessibilityLabel(action.help)
            }
        }
        .padding(4)
        .glassPill()
    }
}

// MARK: Page with a pinned title

private struct HeadingTop: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Hearth's page: the heading scrolls with the page. As it reaches the top it fades out and a
/// glass card with the same title fades in there, and the page keeps scrolling under it.
struct GlassPage<Trailing: View, Content: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    @State private var headingTop: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 while the heading is in place, 1 once it has scrolled 18 points past the top.
    private var progress: CGFloat { min(max(-headingTop / 18, 0), 1) }

    var body: some View {
        let top = $headingTop
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heading
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: HeadingTop.self, value: proxy.frame(in: .named("page")).minY)
                    })
                    .opacity(1 - progress)
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.never)
        .coordinateSpace(name: "page")
        .onPreferenceChange(HeadingTop.self) { top.wrappedValue = $0 }
        .overlay(alignment: .top) { pinned }
    }

    private var heading: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(1.1).foregroundStyle(Theme.faint).lineLimit(1)
                Text(title).font(.system(size: 22, weight: .semibold)).tracking(-0.4).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            trailing
        }
    }

    @ViewBuilder private var pinned: some View {
        if progress > 0 {
            let eased = progress * progress * (3 - 2 * progress)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold)).tracking(-0.25).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(eyebrow).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.horizontal, 14)
            .frame(height: 64)
            .glassBar(radius: 18)
            .compositingGroup()
            .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
            .opacity(eased)
            .offset(y: reduceMotion ? 0 : (1 - eased) * -2)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .allowsHitTesting(progress >= 0.5)
            .accessibilityHidden(progress < 0.5)
        }
    }
}
