import Foundation

/// The trias-energetica phase of a measure. Buying in phase order (first the
/// building envelope, then ventilation, then installations, then generation)
/// earns the "smart order" bonus — just like in real retrofit advice.
public enum MeasurePhase: Int, Codable, Sendable, Comparable, CaseIterable {
    case envelope = 1      // kierdichting, isolatie, glas
    case ventilation = 2   // gecontroleerde ventilatie
    case installation = 3  // warmtepomp, zonneboiler
    case generation = 4    // zonnepanelen

    public static func < (lhs: MeasurePhase, rhs: MeasurePhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum MeasureKind: String, Codable, Sendable, CaseIterable {
    case draughtProofing      // kierdichting
    case roofInsulation       // dakisolatie
    case atticFloorInsulation // zoldervloerisolatie
    case cavityWallInsulation // spouwmuurisolatie
    case interiorWallInsulation // binnengevelisolatie (monumenten)
    case floorInsulation      // vloerisolatie
    case hrGlazing            // HR++-glas
    case tripleGlazing        // triple glas
    case insulatedDoors       // geïsoleerde deuren
    case balancedVentilation  // ventilatie met warmteterugwinning
    case demandVentilation    // CO₂-gestuurde ventilatie
    case hybridHeatPump       // hybride warmtepomp
    case heatPump             // volledig elektrische warmtepomp
    case solarWaterHeater     // zonneboiler
    case solarPanels          // zonnepanelen

    public var phase: MeasurePhase {
        switch self {
        case .draughtProofing, .roofInsulation, .atticFloorInsulation, .cavityWallInsulation,
             .interiorWallInsulation, .floorInsulation, .hrGlazing, .tripleGlazing, .insulatedDoors:
            return .envelope
        case .balancedVentilation, .demandVentilation:
            return .ventilation
        case .hybridHeatPump, .heatPump, .solarWaterHeater:
            return .installation
        case .solarPanels:
            return .generation
        }
    }

    /// Localization keys: "measure.<raw>.name" and "measure.<raw>.tip".
    public var nameKey: String { "measure.\(rawValue).name" }
    public var tipKey: String { "measure.\(rawValue).tip" }

    /// Which visual change the village shows once this measure is done.
    public var visual: HouseVisual {
        switch self {
        case .draughtProofing, .insulatedDoors: return .warmDoor
        case .roofInsulation, .atticFloorInsulation: return .snowOnRoof
        case .cavityWallInsulation, .interiorWallInsulation, .floorInsulation: return .warmWalls
        case .hrGlazing, .tripleGlazing: return .glowingWindows
        case .balancedVentilation, .demandVentilation: return .ventilationGrille
        case .hybridHeatPump, .heatPump: return .heatPumpUnit
        case .solarWaterHeater: return .solarCollector
        case .solarPanels: return .solarPanels
        }
    }
}

/// Visual layers on a house illustration.
public enum HouseVisual: String, Codable, Sendable, CaseIterable {
    case warmDoor, snowOnRoof, warmWalls, glowingWindows, ventilationGrille, heatPumpUnit, solarCollector, solarPanels
}

public struct Measure: Codable, Hashable, Sendable, Identifiable {
    public var kind: MeasureKind
    public var cost: Int
    public var id: String { kind.rawValue }

    public init(kind: MeasureKind, cost: Int) {
        self.kind = kind
        self.cost = cost
    }
}

public struct HouseBlueprint: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// Localization key, e.g. "house.bakery.name".
    public var nameKey: String { "house.\(id).name" }
    public var storyKey: String { "house.\(id).story" }
    public var measures: [Measure]
    /// Grid position in the isometric village (column, row).
    public var gridX: Int
    public var gridY: Int

    public init(id: String, measures: [Measure], gridX: Int, gridY: Int) {
        self.id = id
        self.measures = measures
        self.gridX = gridX
        self.gridY = gridY
    }

    public var maxLabel: EnergyLabel { EnergyLabel.g.raised(by: measures.count) }
    public var totalCost: Int { measures.reduce(0) { $0 + $1.cost } }
}

/// Season 1: eight houses with 6–8 measures each, in the plan's order.
public enum VillageCatalog {
    public static let season1: [HouseBlueprint] = {
        func house(_ id: String, _ index: Int, _ kinds: [MeasureKind], x: Int, y: Int) -> HouseBlueprint {
            // Costs rise per house and per step so later houses take a little longer.
            let base = 40 + index * 18
            let measures = kinds.enumerated().map { step, kind in
                Measure(kind: kind, cost: base + step * (8 + index * 2))
            }
            return HouseBlueprint(id: id, measures: measures, gridX: x, gridY: y)
        }
        return [
            house("bakery", 0, [.draughtProofing, .roofInsulation, .hrGlazing, .cavityWallInsulation,
                                .hybridHeatPump, .solarPanels], x: 0, y: 0),
            house("parsonage", 1, [.draughtProofing, .atticFloorInsulation, .interiorWallInsulation, .hrGlazing,
                                   .floorInsulation, .heatPump, .solarPanels], x: 1, y: 0),
            house("millhouse", 2, [.draughtProofing, .roofInsulation, .floorInsulation, .hrGlazing,
                                   .demandVentilation, .heatPump], x: 2, y: 0),
            house("farmhouse", 3, [.draughtProofing, .roofInsulation, .cavityWallInsulation, .floorInsulation,
                                   .tripleGlazing, .balancedVentilation, .heatPump, .solarPanels], x: 0, y: 1),
            house("schoolhouse", 4, [.draughtProofing, .roofInsulation, .cavityWallInsulation, .hrGlazing,
                                     .demandVentilation, .heatPump, .solarPanels], x: 1, y: 1),
            house("lighthouse", 5, [.draughtProofing, .insulatedDoors, .interiorWallInsulation, .tripleGlazing,
                                    .hybridHeatPump, .solarWaterHeater, .solarPanels], x: 2, y: 1),
            house("station", 6, [.draughtProofing, .roofInsulation, .floorInsulation, .hrGlazing,
                                 .balancedVentilation, .heatPump, .solarPanels], x: 0, y: 2),
            house("manor", 7, [.draughtProofing, .roofInsulation, .cavityWallInsulation, .floorInsulation,
                               .tripleGlazing, .balancedVentilation, .heatPump, .solarPanels], x: 1, y: 2)
        ]
    }()
}
