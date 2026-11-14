import SpriteKit
import UIKit
import HearthsideCore

/// Visual options for the table, derived from settings and selected cosmetics.
struct TableAppearance: Equatable {
    var cardSize: CardSize = .standard
    var highContrast = false
    var leftHanded = false
    var cardBack = "back_hearth"
    var table = "table_oak"
    var fire = "fire_classic"
}

/// Draws all card faces, backs and table textures in code: crisp at any size,
/// no third-party artwork to license, and tiny app size.
@MainActor
final class CardTextureFactory {
    private var cache: [String: SKTexture] = [:]
    private let scale = max(2, UITraitCollection.current.displayScale)

    func face(_ card: Card, size: CGSize, appearance: TableAppearance) -> SKTexture {
        let key = "f\(card.raw)-\(Int(size.width))-\(appearance.cardSize.rawValue)-\(appearance.highContrast)"
        if let cached = cache[key] { return cached }
        let image = render(size: size) { ctx, rect in
            self.drawFace(card, in: rect, context: ctx, appearance: appearance)
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    func back(size: CGSize, style: String) -> SKTexture {
        let key = "b\(style)-\(Int(size.width))"
        if let cached = cache[key] { return cached }
        let image = render(size: size) { ctx, rect in self.drawBack(in: rect, context: ctx, style: style) }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    func slot(size: CGSize, symbol: String?) -> SKTexture {
        let key = "s\(symbol ?? "-")-\(Int(size.width))"
        if let cached = cache[key] { return cached }
        let image = render(size: size) { _, rect in
            let path = UIBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: rect.width * 0.09)
            UIColor.black.withAlphaComponent(0.18).setFill()
            path.fill()
            UIColor(white: 1, alpha: 0.35).setStroke()
            path.lineWidth = 2
            path.stroke()
            if let symbol {
                let font = AppFont.uiFont(size: rect.width * 0.5, bold: true)
                self.drawCentered(symbol, font: font, color: UIColor(white: 1, alpha: 0.35), in: rect)
            }
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    func tableBackground(size: CGSize, style: String) -> SKTexture {
        let key = "t\(style)-\(Int(size.width))x\(Int(size.height))"
        if let cached = cache[key] { return cached }
        let image = render(size: size, opaque: true) { ctx, rect in self.drawTable(in: rect, context: ctx, style: style) }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    func glow(diameter: CGFloat, color: UIColor) -> SKTexture {
        let key = "g\(Int(diameter))-\(color.hash)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: diameter, height: diameter)
        let image = render(size: size) { ctx, rect in
            let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            let center = CGPoint(x: rect.midX, y: rect.midY)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: rect.width / 2, options: [])
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    func purge() { cache.removeAll() }

    // MARK: - Drawing

    private func render(size: CGSize, opaque: Bool = false, _ draw: @escaping (CGContext, CGRect) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext, CGRect(origin: .zero, size: size))
        }
    }

    private func drawFace(_ card: Card, in rect: CGRect, context: CGContext, appearance: TableAppearance) {
        let radius = rect.width * 0.09
        let body = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: radius)
        (appearance.highContrast ? UIColor.white : Palette.cream).setFill()
        body.fill()
        UIColor(white: 0, alpha: appearance.highContrast ? 0.8 : 0.28).setStroke()
        body.lineWidth = appearance.highContrast ? 2 : 1
        body.stroke()

        let red = appearance.highContrast ? Palette.cardRedHighContrast : Palette.cardRed
        let ink = appearance.highContrast ? UIColor.black : Palette.ink
        let color = card.isRed ? red : ink
        let large = appearance.cardSize == .extraLarge
        let pad = rect.width * 0.07

        // Big rank index top-left: the most important thing for older eyes.
        let rankFont = AppFont.uiFont(size: rect.width * (large ? 0.50 : 0.40), bold: true)
        let rankString = NSAttributedString(string: card.rankLabel,
                                            attributes: [.font: rankFont, .foregroundColor: color, .kern: -1])
        let rankSize = rankString.size()
        rankString.draw(at: CGPoint(x: pad, y: pad * 0.4))

        // Suit next to it, top-right.
        let suitFont = UIFont.systemFont(ofSize: rect.width * (large ? 0.40 : 0.32))
        let suitString = NSAttributedString(string: card.suit.symbol, attributes: [.font: suitFont, .foregroundColor: color])
        let suitSize = suitString.size()
        suitString.draw(at: CGPoint(x: rect.maxX - suitSize.width - pad * 0.8, y: pad * 0.4 + (rankSize.height - suitSize.height) / 2))

        // Centre: large suit pip, or a monogram medallion for J/Q/K (no traditional court art).
        let centerRect = CGRect(x: rect.minX, y: rect.height * (large ? 0.50 : 0.42),
                                width: rect.width, height: rect.height * (large ? 0.45 : 0.52))
        if card.rank >= 11 {
            let medallion = centerRect.insetBy(dx: rect.width * 0.18, dy: centerRect.height * 0.12)
            let side = min(medallion.width, medallion.height)
            let circle = CGRect(x: medallion.midX - side / 2, y: medallion.midY - side / 2, width: side, height: side)
            context.setFillColor(color.withAlphaComponent(0.12).cgColor)
            context.fillEllipse(in: circle)
            context.setStrokeColor(color.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: circle.insetBy(dx: 2, dy: 2))
            let crown = card.rank == 13 ? "♚" : (card.rank == 12 ? "♛" : "♞")
            drawCentered(crown, font: UIFont.systemFont(ofSize: side * 0.62), color: color, in: circle)
        } else {
            drawCentered(card.suit.symbol, font: UIFont.systemFont(ofSize: centerRect.height * 0.78), color: color, in: centerRect)
        }
    }

    private func drawBack(in rect: CGRect, context: CGContext, style: String) {
        let palette: (UIColor, UIColor) = {
            switch style {
            case "back_pine": return (Palette.pine, Palette.honey)
            case "back_knit": return (Palette.hearthRed, Palette.cream)
            case "back_starry": return (UIColor(hex: 0x1B2240), UIColor(hex: 0xF5D78E))
            default: return (Palette.eveningBlue, Palette.honey)
            }
        }()
        let radius = rect.width * 0.09
        let body = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: radius)
        Palette.cream.setFill()
        body.fill()
        let inner = UIBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.07, dy: rect.width * 0.07),
                                 cornerRadius: radius * 0.7)
        palette.0.setFill()
        inner.fill()

        context.saveGState()
        inner.addClip()
        // Pattern: diagonal stitches (knit), dots (starry) or diamonds.
        context.setStrokeColor(palette.1.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        let step = rect.width / 6
        var x = -rect.height
        while x < rect.width + rect.height {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            context.move(to: CGPoint(x: x + rect.height, y: 0))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }
        context.strokePath()
        context.restoreGState()

        // Little warm house in the middle.
        let house = CGRect(x: rect.midX - rect.width * 0.2, y: rect.midY - rect.width * 0.18,
                           width: rect.width * 0.4, height: rect.width * 0.36)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: house.minX, y: house.midY))
        path.addLine(to: CGPoint(x: house.midX, y: house.minY))
        path.addLine(to: CGPoint(x: house.maxX, y: house.midY))
        path.addLine(to: CGPoint(x: house.maxX - house.width * 0.12, y: house.midY))
        path.addLine(to: CGPoint(x: house.maxX - house.width * 0.12, y: house.maxY))
        path.addLine(to: CGPoint(x: house.minX + house.width * 0.12, y: house.maxY))
        path.addLine(to: CGPoint(x: house.minX + house.width * 0.12, y: house.midY))
        path.close()
        palette.1.setFill()
        path.fill()
        let window = CGRect(x: house.midX - house.width * 0.1, y: house.midY + house.height * 0.08,
                            width: house.width * 0.2, height: house.height * 0.22)
        palette.0.setFill()
        UIBezierPath(roundedRect: window, cornerRadius: 2).fill()
    }

    private func drawTable(in rect: CGRect, context: CGContext, style: String) {
        let (base, grain): (UIColor, UIColor) = {
            switch style {
            case "table_walnut": return (UIColor(hex: 0x5A3A24), UIColor(hex: 0x3E2716))
            case "table_quilt": return (UIColor(hex: 0x8C3B2E), UIColor(hex: 0x6E2B21))
            case "table_slate": return (UIColor(hex: 0x3B4250), UIColor(hex: 0x2A303B))
            default: return (Palette.wood, Palette.woodDark)
            }
        }()
        base.setFill()
        context.fill(rect)
        // Planks with soft grain lines; deterministic so the texture never "jumps".
        var rng = SeededRandom(seed: UInt64(style.utf8.reduce(7) { $0 &* 31 &+ UInt64($1) }))
        let plank = max(rect.width / 5, 60)
        var x: CGFloat = 0
        while x < rect.width {
            context.setFillColor(grain.withAlphaComponent(0.25).cgColor)
            context.fill(CGRect(x: x, y: 0, width: 1.5, height: rect.height))
            for _ in 0..<14 {
                let gx = x + CGFloat(rng.next(below: Int(plank)))
                context.setStrokeColor(grain.withAlphaComponent(0.10 + Double(rng.next(below: 10)) / 100).cgColor)
                context.setLineWidth(CGFloat(1 + rng.next(below: 2)))
                context.move(to: CGPoint(x: gx, y: 0))
                context.addCurve(to: CGPoint(x: gx + 6, y: rect.height),
                                 control1: CGPoint(x: gx - 8, y: rect.height * 0.3),
                                 control2: CGPoint(x: gx + 12, y: rect.height * 0.7))
                context.strokePath()
            }
            x += plank
        }
        // Vignette so the cards pop.
        let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.35).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1])!
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: max(rect.width, rect.height) * 0.75, options: [.drawsAfterEndLocation])
    }

    private func drawCentered(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) {
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let size = string.size()
        string.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }
}
