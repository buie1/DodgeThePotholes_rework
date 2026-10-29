import Foundation

/// Discriminates every power-up the engine can activate.
enum PowerUpType: Equatable {
    case wrap                    // 15 s — screen-edge wrapping
    case multiplier(Int)         // 30 s — coin multiplier (value = 2 or 3)
    case monsterTruck            // 18 s — invincible, destroys obstacles
    case booze                   // 15 s — inverted controls
    case oneUp                   // instant — +1 life
}

/// Snapshot of an active power-up, including its countdown.
struct PowerUpState: Equatable {
    var type: PowerUpType
    var remainingSeconds: Double
    let totalSeconds: Double

    /// 0.0 (expired) → 1.0 (just activated). Used to drive progress bars.
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, remainingSeconds / totalSeconds)
    }

    /// Display label for HUD timer.
    var timerLabel: String {
        String(format: "%02d", max(0, Int(remainingSeconds.rounded(.up))))
    }
}
