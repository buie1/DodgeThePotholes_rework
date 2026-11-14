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

    func testBundledTuningKeepsLegacyBalance() throws {
        let tuning = try GameTuning.load()
        XCTAssertEqual(tuning.lives.start, 3)
        XCTAssertEqual(tuning.lives.max, 4)
        XCTAssertEqual(tuning.pointsPerSecond, 60)
        XCTAssertEqual(tuning.speed.startTravelDuration, 2.0)
        XCTAssertEqual(tuning.speed.minTravelDuration, 0.2)
        XCTAssertEqual(tuning.spawnIntervals.obstacle, 1.75)
        XCTAssertEqual(tuning.durations.recovery, 4.8)
        XCTAssertEqual(tuning.weights.obstacles.first?.0, .single(.pothole))
        XCTAssertEqual(tuning.weights.obstacles.map(\.1).reduce(0, +), 25)
        XCTAssertEqual(tuning.weights.powerUps.map(\.1).reduce(0, +), 100)
        XCTAssertEqual(tuning.weights.powerUps.last?.0, .nothing)
    }

    func testBundledCatalogKeepsLegacyShop() throws {
        let catalog = try GameCatalog.load()
        XCTAssertEqual(catalog.cars.map(\.id), ["car1", "car2", "car3"])
        XCTAssertEqual(catalog.defaultCar.id, "car1")
        XCTAssertEqual(catalog.shopItems.count, 9)
        XCTAssertEqual(catalog.shopItem(id: "redcar")?.cost, 500)
        XCTAssertEqual(catalog.shopItem(id: "life")?.cost, 1_000)
        XCTAssertEqual(catalog.shopItem(id: "tank")?.cost, 5_000)
    }

    func testEveryCarUnlocksFromACarShopItem() throws {
        let catalog = try GameCatalog.load()
        for car in catalog.cars {
            guard let key = car.unlockKey else { continue }
            XCTAssertEqual(catalog.shopItem(id: key)?.category, .carSkin, "\(car.id) unlock '\(key)'")
        }
        let carUnlocks = Set(catalog.cars.compactMap(\.unlockKey))
        for item in catalog.shopItems where item.category == .carSkin {
            XCTAssertTrue(carUnlocks.contains(item.id), "Shop car '\(item.id)' unlocks no car")
        }
    }

    func testEveryShopImageAndSongIsBundled() throws {
        for item in try GameCatalog.load().shopItems {
            XCTAssertNotNil(UIImage(named: item.imageName, in: .main, with: nil), "Missing shop image: \(item.imageName)")
            if item.category == .song {
                XCTAssertNotNil(GameSound(rawValue: item.id), "Song '\(item.id)' is not a GameSound")
            }
        }
    }

    func testUnknownSpawnNameFailsToDecode() {
        let json = #"{ "obstacles": [{ "spawn": "meteor", "weight": 1 }], "environment": [], "powerUps": [] }"#
        XCTAssertThrowsError(try JSONDecoder().decode(SpawnTables.self, from: Data(json.utf8)))
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
