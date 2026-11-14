import SwiftUI
import UIKit

/// Brand palette from docs/PLAN.md.
enum Palette {
    static let hearthRed = UIColor(hex: 0xC8553D)
    static let honey = UIColor(hex: 0xF2A541)
    static let pine = UIColor(hex: 0x3F6B4F)
    static let eveningBlue = UIColor(hex: 0x2E3A59)
    static let cream = UIColor(hex: 0xFAF3E3)
    static let wood = UIColor(hex: 0x7A5236)
    static let woodDark = UIColor(hex: 0x4E3322)
    static let ink = UIColor(hex: 0x2B2622)
    static let cardRed = UIColor(hex: 0xB3261E)
    static let cardRedHighContrast = UIColor(hex: 0xD10000)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    static let hearthRed = Color(Palette.hearthRed)
    static let honey = Color(Palette.honey)
    static let pine = Color(Palette.pine)
    static let eveningBlue = Color(Palette.eveningBlue)
    static let cream = Color(Palette.cream)
    static let wood = Color(Palette.wood)
    static let woodDark = Color(Palette.woodDark)
    static let ink = Color(Palette.ink)

    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}

/// Nunito (SIL OFL, bundled in Resources/Fonts) with the rounded system font as fallback.
enum AppFont {
    static func nunito(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Nunito-Bold"
        case .semibold: name = "Nunito-SemiBold"
        default: name = "Nunito-Regular"
        }
        if UIFont(name: name, size: 12) != nil {
            return .custom(name, size: UIFont.preferredFont(forTextStyle: style.uiKit).pointSize, relativeTo: style)
        }
        return .system(style, design: .rounded).weight(weight)
    }

    static func uiFont(size: CGFloat, bold: Bool) -> UIFont {
        if let font = UIFont(name: bold ? "Nunito-Bold" : "Nunito-SemiBold", size: size) { return font }
        let base = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .semibold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: rounded, size: size) }
        return base
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .caption: return .caption1
        case .caption2: return .caption2
        case .footnote: return .footnote
        default: return .body
        }
    }
}

/// Big, warm, rounded button used throughout the menus (older players: large tap targets).
struct HearthButtonStyle: ButtonStyle {
    var color: Color = .hearthRed
    var foreground: Color = .cream

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.nunito(.title3, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.gradient)
                    .shadow(color: .black.opacity(0.25), radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Cream card panel on the evening-blue background.
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.cream))
            .foregroundStyle(Color.ink)
    }
}

/// Warm evening gradient used behind menus.
struct HearthBackground: View {
    var body: some View {
        LinearGradient(colors: [Color.eveningBlue, Color(hex: 0x1E2640)], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                RadialGradient(colors: [Color.honey.opacity(0.35), .clear], center: .bottom, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
    }
}

struct WarmthBadge: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").foregroundStyle(Color.honey)
            Text(amount, format: .number)
                .font(AppFont.nunito(.headline, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.3)))
        .foregroundStyle(Color.cream)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("a11y.warmth \(amount)"))
    }
}
