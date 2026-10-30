import Foundation

/// Available player car skins, keyed to legacy asset names.
///
/// The tank is not a skin: owning it replaces the monster-truck power-up sprite.
enum CarSkin: String, CaseIterable, Equatable {
    case blue  = "car1"
    case red   = "car2"
    case green = "car3"

    /// Asset catalog image name for this skin.
    var imageName: String { rawValue }

    /// UserDefaults / UnlockRecord key that gates this skin, if any.
    var unlockKey: String? {
        switch self {
        case .blue:  return nil          // default — always available
        case .red:   return "redcar"
        case .green: return "greencar"
        }
    }

    /// Human-readable display name for the shop / car-select screen.
    var displayName: String {
        switch self {
        case .blue:  return "Blue Racer"
        case .red:   return "Red Rocket"
        case .green: return "Green Machine"
        }
    }
}
