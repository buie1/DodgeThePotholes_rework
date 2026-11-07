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

    // MARK: - Init

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics { startEngine() }
    }

    // MARK: - HapticServiceProtocol

    func play(_ pattern: HapticPattern) {
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
        case .collision:
            // Sharp heavy hit followed by a shorter decay thud.
            events = [
                makeEvent(intensity: 1.0, sharpness: 0.8, duration: 0.25),
                makeEvent(intensity: 0.5, sharpness: 0.3, duration: 0.15, at: 0.20),
            ]

        case .coinPickup:
            // Brief crisp tick — light, high sharpness.
            events = [
                makeEvent(intensity: 0.35, sharpness: 1.0, duration: 0.06),
            ]

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
        }

        guard let hapticPattern = try? CHHapticPattern(events: events, parameters: []) else { return }
        guard let player = try? engine.makePlayer(with: hapticPattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
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
        case .collision:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .coinPickup:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .powerUpActivated:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .lifeGained:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
