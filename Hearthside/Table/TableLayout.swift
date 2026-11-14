import CoreGraphics
import HearthsideCore

/// Pure geometry for the table: where every pile and card goes for a given scene size.
/// SpriteKit coordinates (origin bottom-left, y up); positions are card centres.
struct TableLayout: Equatable {
    var size: CGSize = .zero
    var cardSize: CGSize = .zero
    var margin: CGFloat = 8
    var gap: CGFloat = 6
    var topRowY: CGFloat = 0
    var tableauTopY: CGFloat = 0
    var bottomLimit: CGFloat = 8
    var leftHanded = false
    var faceDownFan: CGFloat = 0
    var faceUpFan: CGFloat = 0

    init() {}

    init(size: CGSize, appearance: TableAppearance) {
        self.size = size
        leftHanded = appearance.leftHanded
        let large = appearance.cardSize == .extraLarge
        margin = large ? 4 : 8
        gap = large ? 3 : 6
        let width = (size.width - margin * 2 - gap * 6) / 7
        // On wide screens (iPad / landscape) don't let cards grow absurdly tall.
        let maxWidth = size.height / (large ? 6.2 : 7.0)
        let cardWidth = min(width, maxWidth)
        cardSize = CGSize(width: cardWidth, height: (cardWidth * 1.42).rounded())
        topRowY = size.height - 10 - cardSize.height / 2
        tableauTopY = topRowY - cardSize.height - 14
        faceDownFan = cardSize.height * 0.14
        faceUpFan = cardSize.height * (large ? 0.36 : 0.30)
    }

    /// Horizontal centre of column `index` (0…6), with columns centred if the cards are narrower.
    func columnX(_ index: Int) -> CGFloat {
        let used = cardSize.width * 7 + gap * 6
        let start = (size.width - used) / 2 + cardSize.width / 2
        return start + CGFloat(index) * (cardSize.width + gap)
    }

    /// Top-row slot for each pile; right-handed: foundations left, waste + stock right.
    var stockPosition: CGPoint { CGPoint(x: columnX(leftHanded ? 0 : 6), y: topRowY) }
    var wastePosition: CGPoint { CGPoint(x: columnX(leftHanded ? 1 : 5), y: topRowY) }
    /// Direction the draw-3 waste fan spreads (towards the centre of the table).
    var wasteFanDirection: CGFloat { leftHanded ? 1 : -1 }

    func foundationPosition(_ suit: Suit) -> CGPoint {
        let slot = leftHanded ? 3 + suit.rawValue : suit.rawValue
        return CGPoint(x: columnX(slot), y: topRowY)
    }

    /// Fan spacing for a column so it never runs off the bottom of the table.
    func fan(for column: Column) -> (down: CGFloat, up: CGFloat) {
        let available = tableauTopY - bottomLimit - cardSize.height / 2
        let downCount = CGFloat(column.faceDownCount)
        let upCount = CGFloat(max(column.faceUpCount - 1, 0))
        let needed = downCount * faceDownFan + upCount * faceUpFan
        guard needed > available, needed > 0 else { return (faceDownFan, faceUpFan) }
        let factor = available / needed
        return (faceDownFan * max(factor, 0.5), faceUpFan * factor)
    }

    func tableauPosition(column: Int, index: Int, in pile: Column) -> CGPoint {
        let fan = fan(for: pile)
        var y = tableauTopY
        for i in 0..<index {
            y -= i < pile.faceDownCount ? fan.down : fan.up
        }
        return CGPoint(x: columnX(column), y: y)
    }

    func wastePosition(index: Int, count: Int, drawCount: Int) -> CGPoint {
        guard drawCount == 3 else { return wastePosition }
        let visible = min(3, count)
        let fromTop = count - 1 - index
        let slot = max(0, visible - 1 - fromTop)
        // slot 0 = oldest visible card, slot 2 = playable top card, furthest towards the centre.
        return CGPoint(x: wastePosition.x + wasteFanDirection * CGFloat(slot) * cardSize.width * 0.3,
                       y: wastePosition.y)
    }

    /// Hit area for dropping on a tableau column: the whole column strip.
    func columnDropRect(_ column: Int, pile: Column) -> CGRect {
        let bottomCard = pile.isEmpty ? tableauTopY : tableauPosition(column: column, index: pile.cards.count - 1, in: pile).y
        let top = tableauTopY + cardSize.height / 2
        let bottom = bottomCard - cardSize.height / 2 - cardSize.height * 0.4
        return CGRect(x: columnX(column) - cardSize.width / 2 - gap / 2, y: bottom,
                      width: cardSize.width + gap, height: top - bottom)
    }

    func slotRect(at center: CGPoint) -> CGRect {
        CGRect(x: center.x - cardSize.width / 2, y: center.y - cardSize.height / 2,
               width: cardSize.width, height: cardSize.height)
    }
}
