import XCTest
@testable import Hearthside
import HearthsideCore

@MainActor
final class TableLayoutTests: XCTestCase {
    func testSevenColumnsFitOnSmallestPhone() {
        for size in [CGSize(width: 320, height: 480), CGSize(width: 375, height: 600), CGSize(width: 430, height: 800)] {
            for cardSize in CardSize.allCases {
                let layout = TableLayout(size: size, appearance: TableAppearance(cardSize: cardSize))
                XCTAssertGreaterThanOrEqual(layout.columnX(0) - layout.cardSize.width / 2, 0)
                XCTAssertLessThanOrEqual(layout.columnX(6) + layout.cardSize.width / 2, size.width + 0.5)
                XCTAssertGreaterThan(layout.cardSize.width, 38, "cards stay readable")
            }
        }
    }

    func testExtraLargeCardsAreBigger() {
        let size = CGSize(width: 390, height: 700)
        let standard = TableLayout(size: size, appearance: TableAppearance(cardSize: .standard))
        let large = TableLayout(size: size, appearance: TableAppearance(cardSize: .extraLarge))
        XCTAssertGreaterThan(large.cardSize.width, standard.cardSize.width)
        XCTAssertGreaterThan(large.faceUpFan, standard.faceUpFan)
    }

    func testLeftHandedMirrorsTopRow() {
        let size = CGSize(width: 390, height: 700)
        let right = TableLayout(size: size, appearance: TableAppearance(leftHanded: false))
        let left = TableLayout(size: size, appearance: TableAppearance(leftHanded: true))
        XCTAssertGreaterThan(right.stockPosition.x, right.foundationPosition(.spades).x)
        XCTAssertLessThan(left.stockPosition.x, left.foundationPosition(.spades).x)
    }

    func testLongColumnsAreCompressedToFit() {
        let layout = TableLayout(size: CGSize(width: 375, height: 560), appearance: TableAppearance())
        let long = Column(cards: (1...13).reversed().map { Card(rank: $0, suit: $0.isMultiple(of: 2) ? .hearts : .spades) },
                          faceDownCount: 6)
        let last = layout.tableauPosition(column: 0, index: 12, in: long)
        XCTAssertGreaterThanOrEqual(last.y - layout.cardSize.height / 2, layout.bottomLimit - 1)
    }

    func testFallbackHintPrefersFoundation() {
        var tableau = Array(repeating: Column(), count: 7)
        tableau[0] = Column(cards: [Card(rank: 1, suit: .hearts)], faceDownCount: 0)
        let state = KlondikeState(stock: [Card(rank: 5, suit: .clubs)], waste: [], foundations: [0, 0, 0, 0], tableau: tableau)
        XCTAssertEqual(GameController.fallbackHint(state: state, rules: .standard()), .tableauToFoundation(0))
    }
}

final class BundleResourceTests: XCTestCase {
    func testWinnableDealsShipInTheBundle() {
        let libraries = DealLibraryLoader.loadAll(bundle: .main) // tests run hosted in the app
        XCTAssertEqual(libraries[1]?.totalCount, 10_000)
        XCTAssertEqual(libraries[3]?.totalCount, 10_000)
    }
}
