import SpriteKit
import UIKit
import HearthsideCore

/// One playing card on the table.
@MainActor
final class CardNode: SKSpriteNode {
    let card: Card
    private(set) var isFaceUp = false
    var faceTexture: SKTexture
    var backTexture: SKTexture

    init(card: Card, face: SKTexture, back: SKTexture, size: CGSize) {
        self.card = card
        self.faceTexture = face
        self.backTexture = back
        super.init(texture: back, color: .clear, size: size)
        name = "card"
        // Soft shadow under every card.
        let shadow = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.22), size: CGSize(width: size.width - 2, height: size.height - 2))
        shadow.position = CGPoint(x: 1.5, y: -2)
        shadow.zPosition = -0.5
        shadow.name = "shadow"
        addChild(shadow)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setFaceUp(_ faceUp: Bool, animated: Bool) {
        guard faceUp != isFaceUp else { return }
        isFaceUp = faceUp
        let target = faceUp ? faceTexture : backTexture
        guard animated else {
            texture = target
            return
        }
        let half = 0.09
        run(.sequence([
            .scaleX(to: 0, duration: half),
            .setTexture(target),
            .scaleX(to: 1, duration: half)
        ]), withKey: "flip")
    }

    func resize(to size: CGSize, face: SKTexture, back: SKTexture) {
        self.size = size
        faceTexture = face
        backTexture = back
        texture = isFaceUp ? face : back
        (childNode(withName: "shadow") as? SKSpriteNode)?.size = CGSize(width: size.width - 2, height: size.height - 2)
    }
}

/// Talks back to the game logic. Implemented by `GameController`.
@MainActor
protocol GameSceneDelegate: AnyObject {
    func sceneDidTapStock()
    func sceneDidTap(_ location: CardLocation)
    /// Returns true when the drop was a legal move (the scene then waits for `sync`).
    func sceneDidDrop(_ location: CardLocation, on target: PileTarget) -> Bool
    func sceneLayoutDidChange(_ items: [AccessibleCard])
}

/// VoiceOver proxy for a card or pile, in SwiftUI (top-left origin) coordinates.
struct AccessibleCard: Identifiable, Equatable {
    var id: String
    var frame: CGRect
    var label: String
    var location: CardLocation
}

/// The SpriteKit table: renders a `KlondikeState`, handles taps and drags, animations,
/// the flickering hearth glow and the win celebration. Holds no game rules itself.
@MainActor
final class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?
    private(set) var layout = TableLayout()
    private var appearance = TableAppearance()
    private let textures = CardTextureFactory()
    private var cardNodes: [UInt8: CardNode] = [:]
    private var locations: [UInt8: CardLocation] = [:]
    private var state: KlondikeState?
    private var drawCount = 1

    private let background = SKSpriteNode()
    private let slotLayer = SKNode()
    private let cardLayer = SKNode()
    private let effectLayer = SKNode()
    private var stockSlot = SKSpriteNode()
    private var wasteSlot = SKSpriteNode()
    private var foundationSlots: [Suit: SKSpriteNode] = [:]
    private var columnSlots: [SKSpriteNode] = []
    private var fireGlow = SKSpriteNode()
    private var embers: SKEmitterNode?

    // Drag state
    private var touchStart: CGPoint = .zero
    private var dragOrigin: CardLocation?
    private var dragNodes: [CardNode] = []
    private var dragOffsets: [CGPoint] = []
    private var isDragging = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = Palette.woodDark
        background.anchorPoint = .zero
        background.zPosition = -10
        addChild(background)
        slotLayer.zPosition = 0
        cardLayer.zPosition = 10
        effectLayer.zPosition = 2_000
        addChild(slotLayer)
        addChild(cardLayer)
        addChild(effectLayer)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        view.ignoresSiblingOrder = true
        rebuildForSize()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0, oldSize != size else { return }
        rebuildForSize()
    }

    // MARK: - Public API

    func configure(appearance: TableAppearance) {
        guard appearance != self.appearance else { return }
        self.appearance = appearance
        textures.purge()
        rebuildForSize()
    }

    /// Moves every card to where `state` says it belongs.
    func sync(_ state: KlondikeState, drawCount: Int, animated: Bool, canDraw: Bool = true) {
        self.state = state
        self.drawCount = drawCount
        guard layout.cardSize.width > 0 else { return }
        ensureCardNodes()
        locations.removeAll(keepingCapacity: true)
        var placements: [(CardNode, CGPoint, CGFloat, Bool, CardLocation)] = []

        for (index, card) in state.stock.enumerated() {
            placements.append((node(card), layout.stockPosition, CGFloat(index) * 0.01, false, .stock))
        }
        for (index, card) in state.waste.enumerated() {
            let pos = layout.wastePosition(index: index, count: state.waste.count, drawCount: drawCount)
            placements.append((node(card), pos, 1 + CGFloat(index) * 0.01, true, .waste))
        }
        for suit in Suit.allCases where state.foundations[suit.rawValue] > 0 {
            for rank in 1...state.foundations[suit.rawValue] {
                placements.append((node(Card(rank: rank, suit: suit)), layout.foundationPosition(suit),
                                   2 + CGFloat(rank) * 0.01, true, .foundation(suit)))
            }
        }
        for (col, pile) in state.tableau.enumerated() {
            for (index, card) in pile.cards.enumerated() {
                let pos = layout.tableauPosition(column: col, index: index, in: pile)
                placements.append((node(card), pos, 3 + CGFloat(index) * 0.01, pile.isFaceUp(index),
                                   .tableau(column: col, index: index)))
            }
        }

        for (cardNode, position, z, faceUp, location) in placements {
            locations[cardNode.card.raw] = location
            cardNode.removeAction(forKey: "hint")
            cardNode.setScale(1)
            if animated && cardNode.position.distance(to: position) > 1 {
                cardNode.zPosition = 500 + z // fly above the others while moving
                let move = SKAction.move(to: position, duration: 0.2)
                move.timingMode = .easeOut
                let finalZ = z * 100
                cardNode.run(.sequence([move, .run { MainActor.assumeIsolated { cardNode.zPosition = finalZ } }]),
                             withKey: "move")
            } else {
                cardNode.removeAction(forKey: "move")
                cardNode.position = position
                cardNode.zPosition = z * 100
            }
            cardNode.setFaceUp(faceUp, animated: animated)
            cardNode.alpha = 1
        }

        stockSlot.texture = textures.slot(size: layout.cardSize, symbol: canDraw ? "↻" : nil)
        publishAccessibility()
    }

    /// Pulses the cards and target of a hinted move.
    func showHint(_ move: Move) {
        guard let state else { return }
        var nodes: [SKNode] = []
        switch move {
        case .draw:
            nodes = state.stock.last.map { [node($0)] } ?? [stockSlot]
        case .wasteToFoundation, .wasteToTableau:
            if let card = state.waste.last { nodes = [node(card)] }
        case .tableauToFoundation(let col):
            if let card = state.tableau[col].top { nodes = [node(card)] }
        case let .tableauToTableau(from, count, _):
            nodes = state.tableau[from].cards.suffix(count).map { node($0) }
        case let .foundationToTableau(suit, _):
            if let card = state.foundationTop(suit) { nodes = [node(card)] }
        }
        if case .tableau(let col)? = move.target {
            nodes.append(state.tableau[col].top.map { node($0) } ?? columnSlots[col])
        }
        let pulse = SKAction.sequence([.scale(to: 1.08, duration: 0.25), .scale(to: 1.0, duration: 0.25)])
        for hinted in nodes {
            hinted.run(.repeat(pulse, count: 3), withKey: "hint")
            let glow = SKSpriteNode(texture: textures.glow(diameter: layout.cardSize.width * 2, color: Palette.honey))
            glow.position = hinted.position
            glow.zPosition = hinted.zPosition - 0.1
            glow.alpha = 0
            glow.blendMode = .add
            effectLayer.addChild(glow)
            glow.run(.sequence([.fadeAlpha(to: 0.7, duration: 0.2), .wait(forDuration: 1.1),
                                .fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
    }

    /// Small shake when a tap has no legal destination.
    func shake(_ location: CardLocation) {
        guard let state, let card = state.card(at: location) else { return }
        let target = node(card)
        let shake = SKAction.sequence([.moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 12, y: 0, duration: 0.08),
                                       .moveBy(x: -6, y: 0, duration: 0.05)])
        target.run(shake)
    }

    /// Cards rise from the table like sparks from the fire.
    func celebrate() {
        for (index, cardNode) in cardNodes.values.enumerated() {
            let delay = Double(index) * 0.025
            let drift = CGFloat.random(in: -60...60)
            let rise = SKAction.moveBy(x: drift, y: size.height * 0.9, duration: 1.6)
            rise.timingMode = .easeIn
            cardNode.run(.sequence([.wait(forDuration: delay),
                                    .group([rise, .fadeOut(withDuration: 1.6), .scale(to: 0.4, duration: 1.6),
                                            .rotate(byAngle: .pi * CGFloat.random(in: -0.5...0.5), duration: 1.6)])]))
        }
        let sparks = makeSparkEmitter()
        sparks.position = CGPoint(x: size.width / 2, y: 0)
        sparks.particlePositionRange = CGVector(dx: size.width, dy: 10)
        effectLayer.addChild(sparks)
        sparks.run(.sequence([.wait(forDuration: 2.2),
                              .run { MainActor.assumeIsolated { sparks.particleBirthRate = 0 } },
                              .wait(forDuration: 3), .removeFromParent()]))
    }

    // MARK: - Building

    private func rebuildForSize() {
        guard size.width > 0, size.height > 0 else { return }
        layout = TableLayout(size: size, appearance: appearance)
        background.texture = textures.tableBackground(size: size, style: appearance.table)
        background.size = size
        buildSlots()
        buildFire()
        for cardNode in cardNodes.values {
            cardNode.resize(to: layout.cardSize, face: faceTexture(cardNode.card), back: backTexture())
        }
        if let state { sync(state, drawCount: drawCount, animated: false) }
    }

    private func buildSlots() {
        slotLayer.removeAllChildren()
        let size = layout.cardSize
        stockSlot = SKSpriteNode(texture: textures.slot(size: size, symbol: "↻"), size: size)
        stockSlot.position = layout.stockPosition
        wasteSlot = SKSpriteNode(texture: textures.slot(size: size, symbol: nil), size: size)
        wasteSlot.position = layout.wastePosition
        slotLayer.addChild(stockSlot)
        slotLayer.addChild(wasteSlot)
        foundationSlots = [:]
        for suit in Suit.allCases {
            let slot = SKSpriteNode(texture: textures.slot(size: size, symbol: suit.symbol), size: size)
            slot.position = layout.foundationPosition(suit)
            foundationSlots[suit] = slot
            slotLayer.addChild(slot)
        }
        columnSlots = (0..<7).map { col in
            let slot = SKSpriteNode(texture: textures.slot(size: size, symbol: "K"), size: size)
            slot.position = CGPoint(x: layout.columnX(col), y: layout.tableauTopY)
            slot.alpha = 0.7
            slotLayer.addChild(slot)
            return slot
        }
    }

    private func buildFire() {
        fireGlow.removeFromParent()
        embers?.removeFromParent()
        let warm = appearance.fire == "fire_lantern" ? UIColor(hex: 0xFFD27A)
            : (appearance.fire == "fire_birch" ? UIColor(hex: 0xFF9E5E) : Palette.honey)
        fireGlow = SKSpriteNode(texture: textures.glow(diameter: max(size.width, 200) * 1.4, color: warm.withAlphaComponent(0.55)))
        fireGlow.position = CGPoint(x: size.width / 2, y: -size.width * 0.35)
        fireGlow.zPosition = -5
        fireGlow.blendMode = .add
        addChild(fireGlow)
        // Gentle, irregular flicker (never strobing).
        var steps: [SKAction] = []
        for _ in 0..<24 {
            let fade = SKAction.fadeAlpha(to: CGFloat.random(in: 0.65...1.0), duration: Double.random(in: 0.18...0.45))
            fade.timingMode = .easeInEaseOut
            steps.append(fade)
            steps.append(.wait(forDuration: 0.25, withRange: 0.3))
        }
        fireGlow.run(.repeatForever(.sequence(steps)))

        let emitter = makeSparkEmitter()
        emitter.particleBirthRate = 1.5
        emitter.particleAlpha = 0.6
        emitter.position = CGPoint(x: size.width / 2, y: -4)
        emitter.particlePositionRange = CGVector(dx: size.width * 0.8, dy: 0)
        emitter.zPosition = -4
        emitter.advanceSimulationTime(4)
        addChild(emitter)
        embers = emitter
    }

    private func makeSparkEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = textures.glow(diameter: 16, color: UIColor(hex: 0xFFC56B))
        emitter.particleBirthRate = 60
        emitter.particleLifetime = 3
        emitter.particleLifetimeRange = 1.5
        emitter.particleSpeed = 90
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 6
        emitter.particleScale = 0.6
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -0.15
        emitter.particleAlphaSpeed = -0.3
        emitter.xAcceleration = 0
        emitter.yAcceleration = 10
        emitter.particleBlendMode = .add
        emitter.particleColor = Palette.honey
        emitter.particleColorBlendFactor = 1
        return emitter
    }

    private func ensureCardNodes() {
        guard cardNodes.isEmpty else { return }
        for card in Card.fullDeck {
            let cardNode = CardNode(card: card, face: faceTexture(card), back: backTexture(), size: layout.cardSize)
            cardNode.position = layout.stockPosition
            cardLayer.addChild(cardNode)
            cardNodes[card.raw] = cardNode
        }
    }

    private func node(_ card: Card) -> CardNode { cardNodes[card.raw]! }
    private func faceTexture(_ card: Card) -> SKTexture { textures.face(card, size: layout.cardSize, appearance: appearance) }
    private func backTexture() -> SKTexture { textures.back(size: layout.cardSize, style: appearance.cardBack) }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let state else { return }
        touchStart = point
        isDragging = false
        dragNodes = []
        dragOrigin = nil

        guard let hit = topCard(at: point), let location = locations[hit.card.raw] else {
            if layout.slotRect(at: layout.stockPosition).contains(point) { dragOrigin = .stock }
            return
        }
        dragOrigin = location
        switch location {
        case .stock:
            return
        case .waste:
            guard hit.card == state.waste.last else { dragOrigin = nil; return }
            dragNodes = [hit]
        case .foundation:
            dragNodes = [hit]
        case let .tableau(column, index):
            let pile = state.tableau[column]
            guard pile.isFaceUp(index) else { dragOrigin = nil; return }
            dragNodes = pile.cards[index...].map { node($0) }
        }
        dragOffsets = dragNodes.map { CGPoint(x: $0.position.x - point.x, y: $0.position.y - point.y) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), !dragNodes.isEmpty else { return }
        if !isDragging && point.distance(to: touchStart) > 8 {
            isDragging = true
            for (offset, cardNode) in dragNodes.enumerated() {
                cardNode.removeAllActions()
                cardNode.setScale(1.04)
                cardNode.zPosition = 10_000 + CGFloat(offset)
            }
        }
        guard isDragging else { return }
        for (cardNode, offset) in zip(dragNodes, dragOffsets) {
            cardNode.position = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            dragNodes = []
            isDragging = false
            dragOrigin = nil
        }
        guard let origin = dragOrigin, let state else { return }
        if !isDragging {
            if case .stock = origin { gameDelegate?.sceneDidTapStock() } else { gameDelegate?.sceneDidTap(origin) }
            return
        }
        if let lead = dragNodes.first, let target = dropTarget(for: lead.frame, in: state),
           gameDelegate?.sceneDidDrop(origin, on: target) == true {
            return
        }
        sync(state, drawCount: drawCount, animated: true) // snap back
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragNodes = []
        isDragging = false
        if let state { sync(state, drawCount: drawCount, animated: true) }
    }

    private func topCard(at point: CGPoint) -> CardNode? {
        nodes(at: point)
            .compactMap { $0 as? CardNode }
            .filter { $0.alpha > 0.1 }
            .max { $0.zPosition < $1.zPosition }
    }

    /// The pile whose drop area overlaps the dragged card the most.
    private func dropTarget(for frame: CGRect, in state: KlondikeState) -> PileTarget? {
        var best: (PileTarget, CGFloat)?
        func consider(_ target: PileTarget, _ rect: CGRect) {
            let overlap = rect.intersection(frame)
            guard !overlap.isNull else { return }
            let area = overlap.width * overlap.height
            if area > (best?.1 ?? 0) { best = (target, area) }
        }
        for suit in Suit.allCases {
            consider(.foundation(suit), layout.slotRect(at: layout.foundationPosition(suit)))
        }
        for col in 0..<7 {
            consider(.tableau(col), layout.columnDropRect(col, pile: state.tableau[col]))
        }
        return best?.0
    }

    // MARK: - Accessibility

    private func publishAccessibility() {
        guard let state else { return }
        var items: [AccessibleCard] = []
        func add(_ id: String, _ position: CGPoint, height: CGFloat? = nil, _ label: String, _ location: CardLocation) {
            let h = height ?? layout.cardSize.height
            let frame = CGRect(x: position.x - layout.cardSize.width / 2,
                               y: size.height - (position.y + layout.cardSize.height / 2),
                               width: layout.cardSize.width, height: h)
            items.append(AccessibleCard(id: id, frame: frame, label: label, location: location))
        }
        let stockLabel = state.stock.isEmpty
            ? String(localized: "a11y.stock.empty")
            : String(localized: "a11y.stock \(state.stock.count)")
        add("stock", layout.stockPosition, stockLabel, .stock)
        if let top = state.waste.last {
            add("waste", layout.wastePosition(index: state.waste.count - 1, count: state.waste.count, drawCount: drawCount),
                String(localized: "a11y.waste \(Self.spoken(top))"), .waste)
        }
        for suit in Suit.allCases {
            let label = state.foundationTop(suit).map { String(localized: "a11y.foundation \(Self.spoken($0))") }
                ?? String(localized: "a11y.foundation.empty \(String(localized: String.LocalizationValue(suit.nameKey)))")
            add("f\(suit.rawValue)", layout.foundationPosition(suit), label, .foundation(suit))
        }
        for (col, pile) in state.tableau.enumerated() {
            if pile.isEmpty {
                add("c\(col)", CGPoint(x: layout.columnX(col), y: layout.tableauTopY),
                    String(localized: "a11y.column.empty \(col + 1)"), .tableau(column: col, index: 0))
                continue
            }
            for index in pile.faceDownCount..<pile.cards.count {
                let position = layout.tableauPosition(column: col, index: index, in: pile)
                let isTop = index == pile.cards.count - 1
                let visibleHeight = isTop ? layout.cardSize.height : layout.fan(for: pile).up
                var label = String(localized: "a11y.column.card \(col + 1) \(Self.spoken(pile.cards[index]))")
                if index == pile.faceDownCount && pile.faceDownCount > 0 {
                    label += ", " + String(localized: "a11y.hidden \(pile.faceDownCount)")
                }
                add("c\(col)-\(index)", position, height: visibleHeight, label, .tableau(column: col, index: index))
            }
        }
        gameDelegate?.sceneLayoutDidChange(items)
    }

    /// "harten zeven" / "seven of hearts".
    static func spoken(_ card: Card) -> String {
        let rank = String(localized: String.LocalizationValue(card.rankNameKey))
        let suit = String(localized: String.LocalizationValue(card.suit.nameKey))
        return String(localized: "a11y.card \(rank) \(suit)")
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
