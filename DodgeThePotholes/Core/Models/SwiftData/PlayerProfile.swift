import Foundation
import SwiftData

/// The player's saved progress and preferences. There is one record per install.
///
/// Replaces the legacy scattered `UserDefaults` keys; see `PersistenceService`
/// for the one-time migration.
@Model
final class PlayerProfile {
    var money: Int = 0
    var highScore: Int = 0
    /// `CarSkin.id` of the car the player drives (`car1` is the free blue car).
    var selectedCarKey: String = "car1"
    var isSFXEnabled: Bool = true
    var isMusicEnabled: Bool = true
    /// `GameSound.rawValue` of the background track played each run.
    var selectedSongFilename: String = GameSound.hotPursuit.rawValue
    /// A bought extra life waiting to be used. The next run spends it.
    var extraLifePending: Bool = false
    /// `ControlScheme.rawValue`: tilt (the legacy default) or drag.
    var controlSchemeKey: String = ControlScheme.tilt.rawValue
    /// Sideways tilt (in g) the player holds the phone at when steering straight.
    var tiltNeutral: Double = 0

    @Relationship(deleteRule: .cascade) var unlocks: [UnlockRecord] = []
    @Relationship(deleteRule: .cascade) var scoreHistory: [ScoreEntry] = []

    init() {}
}
