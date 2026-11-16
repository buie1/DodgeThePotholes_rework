import CoreHaptics
import UIKit

// MARK: - Protocol

/// Plays semantic haptic patterns mapped from engine events.
@MainActor
protocol HapticServiceProtocol: AnyObject {
    func play(_ pattern: HapticPattern)
}

// MARK: - Concrete implementation

/// `CHHapticEngine`-backed haptic service with `UIFeedbackGenerator` fallback.
///
/// **Engine lifecycle**: the engine is started eagerly on init and restarted
/// automatically via `resetHandler` after interruptions (e.g. phone calls).
///
/// **Fallback**: devices that don't support Core Haptics (iPhone 7 and earlier)
/// receive `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` pulses.
@MainActor
final class HapticService: HapticServiceProtocol {

    // MARK: - State

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool
    private var throttle = HapticThrottle()

    // MARK: - Init

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics { startEngine() }
    }

    // MARK: - HapticServiceProtocol

    func play(_ pattern: HapticPattern) {
        guard throttle.allows(pattern, at: CACurrentMediaTime()) else { return }
        supportsHaptics ? playCoreHaptic(pattern) : playFallback(pattern)
    }

    // MARK: - Engine lifecycle

    private func startEngine() {
        guard supportsHaptics else { return }
        do {
            let eng = try CHHapticEngine()
            // Restart automatically after the engine server resets.
            eng.resetHandler = { [weak eng] in
                try? eng?.start()
            }
            // No-op stop handler — engine stops when the app backgrounds.
            eng.stoppedHandler = { _ in }
            try eng.start()
            engine = eng
        } catch {
            // Non-fatal: fallback will be used.
        }
    }

    // MARK: - Core Haptics patterns

    private func playCoreHaptic(_ pattern: HapticPattern) {
        guard let engine else { return }

        let events: [CHHapticEvent]

        switch pattern {
        case .crash:
            // A sharp crack, then a heavy body and a shorter decay thud.
            events = [
                makeTransient(intensity: 1.0, sharpness: 0.9),
                makeEvent(intensity: 0.9, sharpness: 0.3, duration: 0.2),
                makeEvent(intensity: 0.4, sharpness: 0.2, duration: 0.15, at: 0.22),
            ]

        case .spinOut:
            // A low rumble with fading bumps, timed to the 0.75 s spin.
            events = [makeEvent(intensity: 0.35, sharpness: 0.2, duration: 0.6)]
                + (0..<6).map { i in
                    makeTransient(intensity: 0.8 - 0.1 * Float(i), sharpness: 0.4, at: 0.1 * Double(i))
                }

        case .explosion:
            // A short, crisp punch: powerful, not painful.
            events = [
                makeTransient(intensity: 0.8, sharpness: 1.0),
                makeEvent(intensity: 0.5, sharpness: 0.6, duration: 0.12),
            ]

        case .coinPickup:
            // Brief crisp tick — light, high sharpness.
            events = [makeTransient(intensity: 0.35, sharpness: 1.0)]

        case .powerUpActivated:
            // Rising three-pulse burst.
            events = [
                makeEvent(intensity: 0.5, sharpness: 0.4, duration: 0.08),
                makeEvent(intensity: 0.8, sharpness: 0.7, duration: 0.12, at: 0.10),
                makeEvent(intensity: 1.0, sharpness: 1.0, duration: 0.18, at: 0.24),
            ]

        case .lifeGained:
            // Two soft, warm pulses (celebratory double-beat).
            events = [
                makeEvent(intensity: 0.5, sharpness: 0.5, duration: 0.10),
                makeEvent(intensity: 0.7, sharpness: 0.7, duration: 0.12, at: 0.16),
            ]

        case .hornScare:
            // A light double tap, like a honk's two notes.
            events = [
                makeTransient(intensity: 0.45, sharpness: 0.8),
                makeTransient(intensity: 0.45, sharpness: 0.8, at: 0.08),
            ]

        case .nearMiss:
            // A quick, crisp tick: close, but clean.
            events = [makeTransient(intensity: 0.55, sharpness: 1.0)]

        case .comboLevelUp:
            // Two rising taps: the combo stepping up.
            events = [
                makeTransient(intensity: 0.6, sharpness: 0.7),
                makeTransient(intensity: 0.9, sharpness: 1.0, at: 0.09),
            ]

        case .gameOver:
            // A long thud that fades out, after the crash that caused it.
            events = [
                makeEvent(intensity: 0.8, sharpness: 0.2, duration: 0.25, at: 0.3),
                makeEvent(intensity: 0.5, sharpness: 0.15, duration: 0.25, at: 0.55),
                makeEvent(intensity: 0.25, sharpness: 0.1, duration: 0.3, at: 0.8),
            ]
        }

        guard let hapticPattern = try? CHHapticPattern(events: events, parameters: []) else { return }
        guard let player = try? engine.makePlayer(with: hapticPattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    /// Convenience builder for a crisp `.hapticTransient` tap.
    private func makeTransient(intensity: Float, sharpness: Float, at relativeTime: TimeInterval = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: relativeTime
        )
    }

    /// Convenience builder for a `.hapticContinuous` event.
    private func makeEvent(
        intensity: Float,
        sharpness: Float,
        duration: TimeInterval,
        at relativeTime: TimeInterval = 0
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: relativeTime,
            duration: duration
        )
    }

    // MARK: - UIFeedbackGenerator fallback

    private func playFallback(_ pattern: HapticPattern) {
        switch pattern {
        case .crash, .spinOut:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .explosion:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .coinPickup, .hornScare, .nearMiss:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .comboLevelUp:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .powerUpActivated, .lifeGained:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .gameOver:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Throttle

/// Drops light ticks that would fire too close together to feel distinct.
struct HapticThrottle {
    /// Ticks closer together than this blur into a buzz (e.g. driving through a coin pattern).
    static let tickInterval: TimeInterval = 0.07

    private var lastTick: [HapticPattern: TimeInterval] = [:]

    /// Whether `pattern` should play at `time` (seconds); records it if so.
    /// Only coin and near-miss ticks are throttled.
    mutating func allows(_ pattern: HapticPattern, at time: TimeInterval) -> Bool {
        guard pattern == .coinPickup || pattern == .nearMiss else { return true }
        guard time - (lastTick[pattern] ?? -.infinity) >= Self.tickInterval else { return false }
        lastTick[pattern] = time
        return true
    }
}
