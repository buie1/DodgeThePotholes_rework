import XCTest
import UIKit
@testable import DodgeThePotholes

/// Verifies every legacy resource ported in step 1 is bundled and loadable.
final class ResourceTests: XCTestCase {

    func testEveryGameSoundIsBundled() {
        for sound in GameSound.allCases {
            let file = sound.rawValue as NSString
            let url = Bundle.main.url(forResource: file.deletingPathExtension,
                                      withExtension: file.pathExtension)
            XCTAssertNotNil(url, "Missing audio file: \(sound.rawValue)")
        }
    }

    func testEverySpriteLoads() {
        for name in SpriteCatalog.allImageNames {
            XCTAssertNotNil(UIImage(named: name, in: .main, with: nil), "Missing sprite: \(name)")
        }
    }

    func testEveryPatternDecodes() throws {
        for name in TilePattern.Name.allCases {
            let pattern = try TilePattern.load(name)
            XCTAssertEqual(pattern.tiles.count, pattern.numRows, "\(name.rawValue) row count")
            XCTAssertTrue(pattern.tiles.allSatisfy { $0.count == pattern.numCols },
                          "\(name.rawValue) column count")
        }
    }

    func testPatternGridIsBottomUp() throws {
        let pattern = try TilePattern.load(.money1)
        let grid = pattern.grid
        // Top-left JSON tile lands in the top row of the grid.
        XCTAssertEqual(grid[0, pattern.numRows - 1], pattern.tiles[0][0] == 0 ? nil : pattern.tiles[0][0])
    }

    func testPixelFontIsRegistered() {
        XCTAssertNotNil(UIFont(name: "PressStart2P", size: 12))
    }

    func testAllLegacyLyricsAreShownInOrderThenWrap() {
        XCTAssertEqual(TextMessageLyrics.lines.count, 58)
        XCTAssertEqual(GameConfig.textMessageCount, TextMessageLyrics.lines.count)
        XCTAssertEqual(TextMessageLyrics.line(at: 0), "We're no strangers to love")
        XCTAssertEqual(TextMessageLyrics.line(at: 57), "Never gonna tell a lie and hurt you")
        XCTAssertEqual(TextMessageLyrics.line(at: 58), TextMessageLyrics.line(at: 0))
    }

    func testExplosionEmitterLoads() {
        XCTAssertNotNil(Bundle.main.url(forResource: "Explosion", withExtension: "sks"))
    }
}
