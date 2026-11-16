import CoreMotion

// MARK: - Protocol

/// Streams device tilt as normalised steering input.
/// Conforming types must be class-bound so `GameViewModel` can hold them by reference.
protocol MotionServiceProtocol: AnyObject {
    /// `false` when the device has no accelerometer (e.g. the Simulator).
    var isAvailable: Bool { get }

    /// Sideways tilt (in g) that counts as straight ahead; set by calibration.
    var neutralTilt: Double { get set }

    /// The latest raw sideways tilt (in g) while updates are running; `nil` before the first.
    var rawTilt: Double? { get }

    /// Begins delivering steering values in [-1, 1] on the main thread.
    /// Positive = tilted right. Replaces any previous handler.
    func start(onTilt: @escaping @MainActor (Double) -> Void)

    /// Stops delivering updates.
    func stop()
}

// MARK: - Concrete implementation

/// `CMMotionManager`-backed tilt steering, as in the legacy game:
/// hold the phone flat and lean it left or right.
final class MotionService: MotionServiceProtocol {

    private let manager = CMMotionManager()

    var isAvailable: Bool { manager.isAccelerometerAvailable }
    var neutralTilt: Double = 0
    private(set) var rawTilt: Double?

    func start(onTilt: @escaping @MainActor (Double) -> Void) {
        guard isAvailable else { return }
        manager.stopAccelerometerUpdates()
        manager.accelerometerUpdateInterval = GameConfig.tiltUpdateInterval
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let x = data?.acceleration.x else { return }
            self.rawTilt = x
            let steering = max(-1, min(1, (x - self.neutralTilt) * GameConfig.tiltSensitivity))
            MainActor.assumeIsolated { onTilt(steering) }
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
    }
}
