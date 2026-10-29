import XCTest
@testable import DodgeThePotholes

/// Steering and horn input rules: tilt by default, drag overrides, tap honks.
@MainActor
final class GameViewModelInputTests: XCTestCase {

    private var motion: MockMotionService!
    private var viewModel: GameViewModel!

    override func setUp() {
        super.setUp()
        motion = MockMotionService()
        viewModel = GameViewModel(audio: MockAudioService(), haptics: MockHapticService(),
                                  scores: MockScoreService(), motion: motion)
        viewModel.startGame(screenSize: CGSize(width: 402, height: 874))
    }

    private var playerX: Double { viewModel.engine!.player.position.x }

    func testTiltSteersTheCar() {
        motion.tilt(0.5)
        viewModel.engine!.update(deltaTime: 0.05)
        XCTAssertGreaterThan(playerX, 0)
    }

    func testDragOverridesTiltUntilReleased() {
        motion.tilt(0.5)
        viewModel.updateDrag(-1)
        viewModel.engine!.update(deltaTime: 0.05)
        let afterDrag = playerX
        XCTAssertLessThan(afterDrag, 0, "drag wins over tilt")

        viewModel.endDrag(wasTap: false)
        viewModel.engine!.update(deltaTime: 0.05)
        XCTAssertGreaterThan(playerX, afterDrag, "tilt resumes after release")
        XCTAssertTrue(viewModel.engine!.horns.isEmpty, "a drag is not a honk")
    }

    func testTapHonks() {
        viewModel.updateDrag(0)
        viewModel.endDrag(wasTap: true)
        XCTAssertEqual(viewModel.engine!.horns.count, 1)
    }

    func testMotionStopsWhenLeavingTheGame() {
        XCTAssertEqual(motion.startCount, 1)
        viewModel.returnToMenu()
        XCTAssertEqual(motion.stopCount, 1)
    }

    func testWithoutAccelerometerOnlyDragSteers() {
        let noTilt = MockMotionService(isAvailable: false)
        let vm = GameViewModel(audio: MockAudioService(), haptics: MockHapticService(),
                               scores: MockScoreService(), motion: noTilt)
        vm.startGame(screenSize: CGSize(width: 402, height: 874))
        XCTAssertFalse(vm.isTiltAvailable)

        vm.updateDrag(1)
        vm.engine!.update(deltaTime: 0.05)
        XCTAssertGreaterThan(vm.engine!.player.position.x, 0)
    }
}

// MARK: - Test doubles

final class MockMotionService: MotionServiceProtocol {
    let isAvailable: Bool
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var handler: (@MainActor (Double) -> Void)?

    init(isAvailable: Bool = true) { self.isAvailable = isAvailable }

    func start(onTilt: @escaping @MainActor (Double) -> Void) {
        startCount += 1
        guard isAvailable else { return }
        handler = onTilt
    }

    func stop() {
        stopCount += 1
        handler = nil
    }

    /// Simulates a tilt reading.
    @MainActor func tilt(_ value: Double) { handler?(value) }
}

final class MockAudioService: AudioServiceProtocol {
    var isMusicEnabled = true
    var isSFXEnabled = true
    func play(_ sound: GameSound) {}
    func startMusic(_ track: GameSound) {}
    func stopMusic() {}
    func setDrunkMode(_ enabled: Bool) {}
}

final class MockHapticService: HapticServiceProtocol {
    func play(_ pattern: HapticPattern) {}
}

final class MockScoreService: ScoreServiceProtocol {
    var highScore = 0
    func save(score: Int) -> Bool { false }
    func reset() {}
}
