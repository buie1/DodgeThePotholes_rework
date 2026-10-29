import Foundation
import CoreGraphics

/// Discriminates every power-up the engine can activate.
enum PowerUpType: Equatable {
    case wrap                    // 15 s — screen-edge wrapping
    case multiplier(Int)         // 30 s — coin multiplier (value = 2 or 3)
    case monsterTruck            // 18 s — invincible, destroys obstacles
    case booze                   // 15 s — inverted controls
    case oneUp                   // instant — +1 life

    /// `true` when both values are the same power-up, ignoring a multiplier's value.
    func isSameKind(as other: PowerUpType) -> Bool {
        switch (self, other) {
        case (.multiplier, .multiplier): return true
        default: return self == other
        }
    }

    /// Pickup sprite size in world units (legacy per-class sizes).
    var spawnSize: CGSize {
        switch self {
        case .wrap, .multiplier: return CGSize(width: 50, height: 50)
        case .oneUp, .monsterTruck: return CGSize(width: 50, height: 51)
        case .booze: return CGSize(width: 30, height: 60)
        }
    }
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
