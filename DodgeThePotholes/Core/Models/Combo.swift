import Foundation

/// The run's combo: chained actions build a score multiplier that lapses when idle.
struct Combo: Equatable {
    let rules: GameTuning.Combo
    /// Actions chained since the combo started.
    private(set) var chain = 0
    /// Seconds left before the combo lapses without a new action.
    private(set) var timeLeft: Double = 0

    init(rules: GameTuning.Combo) {
        self.rules = rules
    }

    /// x1 with no combo, rising one level every `actionsPerLevel` actions up to `maxMultiplier`.
    var multiplier: Int { min(rules.maxMultiplier, 1 + chain / rules.actionsPerLevel) }

    var isActive: Bool { chain > 0 }

    /// Adds `actions` to the chain and restarts the timer.
    /// - Returns: `true` when the multiplier went up.
    @discardableResult
    mutating func add(actions: Int) -> Bool {
        let before = multiplier
        chain += actions
        timeLeft = rules.window
        return multiplier > before
    }

    /// Runs the timer down; the combo lapses when it reaches zero.
    mutating func tick(dt: Double) {
        guard isActive else { return }
        timeLeft -= dt
        if timeLeft <= 0 { reset() }
    }

    mutating func reset() {
        chain = 0
        timeLeft = 0
    }
}
