import SwiftUI
import HearthsideCore

/// Shapes and silhouettes per house, so each of the eight looks distinct.
enum HouseShape {
    case cottage, tall, mill, barn, school, lighthouse, station, manor

    init(houseID: String) {
        switch houseID {
        case "parsonage": self = .tall
        case "millhouse": self = .mill
        case "farmhouse": self = .barn
        case "schoolhouse": self = .school
        case "lighthouse": self = .lighthouse
        case "station": self = .station
        case "manor": self = .manor
        default: self = .cottage
        }
    }

    var wallColor: Color {
        switch self {
        case .cottage: return Color(hex: 0xD9A273)
        case .tall: return Color(hex: 0xC9B79C)
        case .mill: return Color(hex: 0xB8865B)
        case .barn: return Color(hex: 0xA44A3F)
        case .school: return Color(hex: 0xC97B5A)
        case .lighthouse: return Color(hex: 0xEDE6DA)
        case .station: return Color(hex: 0x9C6B4E)
        case .manor: return Color(hex: 0xD8C3A5)
        }
    }

    var roofColor: Color {
        switch self {
        case .barn, .mill: return Color(hex: 0x5B4636)
        case .lighthouse: return Color.hearthRed
        case .manor, .tall: return Color(hex: 0x4A5363)
        default: return Color(hex: 0x6E3B2E)
        }
    }

    var windowCount: Int {
        switch self {
        case .manor, .school, .station: return 4
        case .tall, .barn: return 3
        default: return 2
        }
    }

    var widthRatio: CGFloat {
        switch self {
        case .lighthouse, .tall: return 0.55
        case .manor, .station, .barn: return 0.95
        default: return 0.75
        }
    }
}

/// A hand-drawn-style house that visibly warms up as measures are completed:
/// cold grey and smoking chimney at G → snow-capped roof, glowing windows,
/// heat pump and solar panels at A.
struct HouseIllustration: View {
    let houseID: String
    let label: EnergyLabel
    let visuals: Set<HouseVisual>
    var locked = false
    @State private var flicker = false

    private var shape: HouseShape { HouseShape(houseID: houseID) }
    private var warmth: Double { label.warmth }

    var body: some View {
        GeometryReader { geo in
            let frame = HouseFrame(size: geo.size, shape: shape)
            ZStack {
                skyLayer(frame)
                roofLayer(frame)
                wallLayer(frame)
                extrasLayer(frame)
            }
            .saturation(locked ? 0 : 0.35 + 0.65 * warmth)
            .opacity(locked ? 0.45 : 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { flicker = true }
        }
        .accessibilityHidden(true)
    }

    /// Warm halo, chimney smoke and the chimney itself.
    @ViewBuilder
    private func skyLayer(_ f: HouseFrame) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color.honey.opacity(0.55 * warmth), .clear],
                                 center: .center, startRadius: 4, endRadius: f.width * 0.6))
            .frame(width: f.width * 1.2, height: f.width * 1.2)
            .position(x: f.width / 2, y: f.body.midY)
        // Smoke disappears as the house gets efficient (heat pump = no smoke).
        if !visuals.contains(.heatPumpUnit) {
            SmokeView(intensity: 1 - warmth)
                .frame(width: f.width * 0.2, height: f.height * 0.35)
                .position(x: f.chimneyX, y: f.body.minY - f.height * 0.28)
        }
        Rectangle()
            .fill(Color(hex: 0x5B4636))
            .frame(width: f.body.width * 0.1, height: f.height * 0.14)
            .position(x: f.chimneyX, y: f.body.minY - f.height * 0.08)
    }

    /// Roof, snow on an insulated roof, solar panels and collector.
    @ViewBuilder
    private func roofLayer(_ f: HouseFrame) -> some View {
        RoofShape(kind: shape)
            .fill(shape.roofColor.saturated(warmth))
            .frame(width: f.body.width * 1.15, height: f.height * 0.25)
            .position(x: f.width / 2, y: f.body.minY - f.height * 0.1)
        if visuals.contains(.snowOnRoof) {
            RoofShape(kind: shape)
                .fill(Color.white.opacity(0.95))
                .frame(width: f.body.width * 1.15, height: f.height * 0.08)
                .position(x: f.width / 2, y: f.body.minY - f.height * 0.18)
        }
        if visuals.contains(.solarPanels) {
            SolarPanels()
                .frame(width: f.body.width * 0.5, height: f.height * 0.07)
                .rotationEffect(.degrees(-12))
                .position(x: f.width / 2 - f.body.width * 0.12, y: f.body.minY - f.height * 0.08)
        }
        if visuals.contains(.solarCollector) {
            Rectangle().fill(Color(hex: 0x2E4A3A))
                .frame(width: f.body.width * 0.18, height: f.height * 0.06)
                .rotationEffect(.degrees(12))
                .position(x: f.width / 2 + f.body.width * 0.2, y: f.body.minY - f.height * 0.06)
        }
    }

    /// Walls, windows and the door.
    @ViewBuilder
    private func wallLayer(_ f: HouseFrame) -> some View {
        let insulated = visuals.contains(.warmWalls)
        RoundedRectangle(cornerRadius: 3)
            .fill(shape.wallColor.saturated(warmth))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(insulated ? Color.honey.opacity(0.9) : Color.black.opacity(0.25), lineWidth: insulated ? 2 : 1))
            .frame(width: f.body.width, height: f.body.height)
            .position(x: f.body.midX, y: f.body.midY)
        HStack(spacing: f.body.width * 0.08) {
            ForEach(0..<shape.windowCount, id: \.self) { index in
                WindowView(lit: windowLit(index), glazed: visuals.contains(.glowingWindows), flicker: flicker)
            }
        }
        .frame(width: f.body.width * 0.8, height: f.body.height * 0.28)
        .position(x: f.body.midX, y: f.body.minY + f.body.height * 0.32)
        DoorView(warm: visuals.contains(.warmDoor), symbolSize: f.body.width * 0.08)
            .frame(width: f.body.width * 0.16, height: f.body.height * 0.36)
            .position(x: f.body.midX, y: f.groundY - f.body.height * 0.18)
    }

    /// Heat pump unit, ventilation grille and the ground.
    @ViewBuilder
    private func extrasLayer(_ f: HouseFrame) -> some View {
        if visuals.contains(.heatPumpUnit) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: 0xE8E8E8))
                .overlay(Circle().stroke(Color.gray, lineWidth: 1).padding(3))
                .frame(width: f.body.width * 0.18, height: f.body.height * 0.2)
                .position(x: f.body.maxX + f.body.width * 0.08, y: f.groundY - f.body.height * 0.1)
        }
        if visuals.contains(.ventilationGrille) {
            Capsule().fill(Color.gray.opacity(0.7))
                .frame(width: f.body.width * 0.12, height: f.body.height * 0.05)
                .position(x: f.body.minX + f.body.width * 0.15, y: f.body.minY + f.body.height * 0.1)
        }
        Capsule()
            .fill(Color(hex: 0x2D4A37).opacity(0.9))
            .frame(width: f.width * 0.95, height: f.height * 0.08)
            .position(x: f.width / 2, y: f.groundY + f.height * 0.02)
    }

    private func windowLit(_ index: Int) -> Bool {
        // More windows light up as the label rises.
        let litCount = Int((Double(shape.windowCount) * warmth).rounded(.up))
        return index < litCount
    }
}

/// Precomputed geometry so the view builders stay simple for the type checker.
private struct HouseFrame {
    let width: CGFloat
    let height: CGFloat
    let body: CGRect
    let groundY: CGFloat
    let chimneyX: CGFloat

    init(size: CGSize, shape: HouseShape) {
        width = size.width
        height = size.height
        let bodyWidth = size.width * shape.widthRatio
        let tall = shape == .lighthouse || shape == .tall
        let bodyHeight = size.height * (tall ? 0.6 : 0.45)
        groundY = size.height * 0.92
        body = CGRect(x: (size.width - bodyWidth) / 2, y: groundY - bodyHeight, width: bodyWidth, height: bodyHeight)
        chimneyX = body.maxX - bodyWidth * 0.22
    }
}

private struct SolarPanels: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle().fill(Color(hex: 0x23395B))
                    .overlay(Rectangle().stroke(Color(hex: 0x9FB3D1), lineWidth: 0.5))
            }
        }
    }
}

/// Door: a little heart on a red door once draught-proofed (a nod to the app icon).
private struct DoorView: View {
    let warm: Bool
    let symbolSize: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(warm ? Color.hearthRed : Color(hex: 0x5B4636))
            .overlay {
                if warm {
                    Text("♥").font(.system(size: symbolSize)).foregroundStyle(Color.cream)
                }
            }
    }
}

private struct WindowView: View {
    let lit: Bool
    let glazed: Bool
    let flicker: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(lit ? Color.honey.opacity(flicker ? 0.95 : 0.8) : Color(hex: 0x3A4256))
            .overlay(
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.4)).frame(width: 1.5)
                    Rectangle().fill(Color.black.opacity(0.4)).frame(height: 1.5)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(glazed ? Color.white : Color.black.opacity(0.4),
                                                              lineWidth: glazed ? 1.5 : 1))
            .shadow(color: lit ? Color.honey.opacity(0.8) : .clear, radius: lit ? 4 : 0)
    }
}

private struct RoofShape: Shape {
    let kind: HouseShape

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .lighthouse:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.8, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.2, y: rect.maxY))
        case .barn, .station:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.35))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.35))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        default:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// Soft drifting chimney smoke (TimelineView keeps it cheap and smooth).
private struct SmokeView: View {
    let intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<5 {
                    let phase = (t * 0.25 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                    let y = size.height * (1 - phase)
                    let x = size.width / 2 + sin(phase * 6 + Double(i)) * size.width * 0.25
                    let r = size.width * (0.15 + phase * 0.35)
                    ctx.opacity = (1 - phase) * 0.55 * intensity
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(white: 0.75)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private extension Color {
    /// Cold houses look washed out; warmth brings the colour back.
    func saturated(_ warmth: Double) -> Color {
        self.opacity(0.75 + 0.25 * warmth)
    }
}
