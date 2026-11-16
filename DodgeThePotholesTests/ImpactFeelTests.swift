import XCTest
import SpriteKit
@testable import DodgeThePotholes

/// Hit events from the engine and the renderer's shake / hit-stop response.
@MainActor
final class ImpactFeelTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)

    /// A point inside the player's hit box (front half of the car).
    private var hitPoint: CGPoint { CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset + 40) }

    private func makeEngine() -> GameEngine {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        return engine
    }

    private func place(_ type: ObstacleType, in engine: GameEngine) {
        engine.insert(ObstacleEntity(id: UUID(), position: hitPoint, size: type.size, velocity: .zero, type: type))
    }

    // MARK: - Engine events

    func testCrashingIntoACarEmitsCrashAtTheObstacle() {
        let engine = makeEngine()
        place(.movingCar, in: engine)
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.frameEvents, [.crash(at: hitPoint)])
    }

    func testPotholeEmitsSpinOutNotCrash() {
        let engine = makeEngine()
        place(.pothole, in: engine)
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.frameEvents, [.spinOut])
    }

    func testTextMessageIsNotAnImpact() {
        let engine = makeEngine()
        place(.textMessage, in: engine)
        engine.update(deltaTime: 0.016)
        XCTAssertTrue(engine.frameEvents.isEmpty)
    }

    // MARK: - Camera

    func testCameraHoldsThenShakesThenSettles() {
        let camera = ImpactCamera(worldSize: world)
        camera.impact(.crash)

        XCTAssertTrue(camera.holdsAction(for: 0.05))
        XCTAssertTrue(camera.holdsAction(for: 0.05))
        XCTAssertFalse(camera.holdsAction(for: 0.05), "hit-stop lasts ImpactFeel.crash.hitStop")

        camera.update(dt: 0.05)
        XCTAssertLessThan(camera.xScale, 1, "zoomed in while shaking")
        for _ in 0..<10 { camera.update(dt: 0.05) }
        XCTAssertEqual(camera.position, .zero)
        XCTAssertEqual(camera.xScale, 1)
    }

    func testExplosionsNeverFreezeTheAction() {
        let camera = ImpactCamera(worldSize: world)
        camera.impact(.explosion)
        XCTAssertFalse(camera.holdsAction(for: 0.016))
    }

    // MARK: - Scene

    func testSceneHoldsTheEngineDuringHitStop() {
        let engine = makeEngine()
        let scene = GameRenderScene(engine: engine)
        place(.movingCar, in: engine)

        scene.update(0)
        scene.update(0.016)          // the crash happens here
        let afterHit = engine.elapsed
        scene.update(0.032)          // frozen
        XCTAssertEqual(engine.elapsed, afterHit)

        for frame in 3...20 { scene.update(Double(frame) * 0.016) }
        XCTAssertGreaterThan(engine.elapsed, afterHit, "the action resumes after the hit-stop")
    }
}
