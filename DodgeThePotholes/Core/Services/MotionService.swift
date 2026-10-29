import CoreMotion

// MARK: - Protocol

/// Streams device tilt as normalised steering input.
/// Conforming types must be class-bound so `GameViewModel` can hold them by reference.
protocol MotionServiceProtocol: AnyObject {
    /// `false` when the device has no accelerometer (e.g. the Simulator).
    var isAvailable: Bool { get }

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

    func start(onTilt: @escaping @MainActor (Double) -> Void) {
        guard isAvailable else { return }
        manager.stopAccelerometerUpdates()
        manager.accelerometerUpdateInterval = GameConfig.tiltUpdateInterval
        manager.startAccelerometerUpdates(to: .main) { data, _ in
            guard let x = data?.acceleration.x else { return }
            let steering = max(-1, min(1, x * GameConfig.tiltSensitivity))
            MainActor.assumeIsolated { onTilt(steering) }
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
    }
}
