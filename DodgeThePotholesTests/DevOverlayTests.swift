import XCTest
import SpriteKit
@testable import DodgeThePotholes

/// The in-run DEV overlay's hooks: frame stepping, dev-adjusted runs and hit boxes.
@MainActor
final class DevOverlayTests: XCTestCase {

    private let screen = CGSize(width: 402, height: 874)

    func testStepAdvancesOneFrameOnlyWhilePaused() {
        let engine = GameEngine(worldSize: CGSize(width: 750, height: 1334), tables: .none,
                                rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        engine.stepWhilePaused()
        XCTAssertEqual(engine.elapsed, 0, "ignored while playing")

        engine.pause()
        engine.stepWhilePaused()
        XCTAssertEqual(engine.elapsed, 1.0 / 60, accuracy: 1e-9)
        XCTAssertEqual(engine.state, .paused)
    }

    func testAdjustedNormalRunIsNeitherRecordedNorSubmitted() async {
        let persistence = MockPersistenceService()
        let leaderboard = MockLeaderboardService()
        let viewModel = GameViewModel(persistence: persistence, audio: MockAudioService(),
                                      haptics: MockHapticService(), motion: MockMotionService(),
                                      leaderboard: leaderboard)
        viewModel.startGame(screenSize: screen)
        viewModel.devAdjust { $0.debug.godMode = true }
        XCTAssertTrue(viewModel.engine!.debug.godMode)

        viewModel.engineDidEnd(viewModel.engine!, finalScore: 50_000, moneyEarned: 10)
        await Task.yield()
        XCTAssertTrue(persistence.runs.isEmpty)
        XCTAssertTrue(leaderboard.submittedScores.isEmpty)

        // The next, untouched run counts again.
        viewModel.startGame(screenSize: screen)
        viewModel.engineDidEnd(viewModel.engine!, finalScore: 10, moneyEarned: 1)
        XCTAssertEqual(persistence.runs.count, 1)
    }

    func testHitboxesDrawTheCollisionRects() throws {
        let engine = GameEngine(worldSize: CGSize(width: 750, height: 1334), tables: .none,
                                rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        engine.spawnNow(ObstacleSpawn.single(.pothole))
        let scene = GameRenderScene(engine: engine)

        scene.showsHitboxes = true
        scene.debugRedraw()
        let shapes = scene.children.flatMap(\.children).compactMap { $0 as? SKShapeNode }
        XCTAssertEqual(shapes.count, 5)
        XCTAssertEqual(shapes[0].path?.boundingBox, engine.player.collisionRect, "player box")
        XCTAssertEqual(shapes[1].path?.boundingBox, engine.obstacles[0].collisionRect, "pothole box")

        scene.showsHitboxes = false
        scene.debugRedraw()
        XCTAssertTrue(scene.children.flatMap(\.children).compactMap { $0 as? SKShapeNode }.isEmpty)
    }
}
