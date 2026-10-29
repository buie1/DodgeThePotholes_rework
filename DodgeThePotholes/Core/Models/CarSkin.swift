import Foundation

/// Available player car skins, keyed to legacy asset names.
enum CarSkin: String, CaseIterable, Equatable {
    case blue  = "car1"
    case red   = "car2"
    case green = "car3"
    case tank  = "tank"

    /// Asset catalog image name for this skin.
    var imageName: String { rawValue }

    /// UserDefaults / UnlockRecord key that gates this skin, if any.
    var unlockKey: String? {
        switch self {
        case .blue:  return nil          // default — always available
        case .red:   return "redcar"
        case .green: return "greencar"
        case .tank:  return "tank"
        }
    }

    /// Human-readable display name for the shop / car-select screen.
    var displayName: String {
        switch self {
        case .blue:  return "Blue Racer"
        case .red:   return "Red Rocket"
        case .green: return "Green Machine"
        case .tank:  return "Tank"
        }
    }
}
