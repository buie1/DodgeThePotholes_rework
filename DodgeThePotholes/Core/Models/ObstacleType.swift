import CoreGraphics

/// All obstacle and hazard types the engine can spawn.
enum ObstacleType: String, CaseIterable, Equatable {
    // MARK: Static obstacles
    case pothole
    case blackIce
    case cone
    case barricade
    case plant
    case textMessage

    // MARK: Animated / moving vehicles
    case movingCar
    case ambulance
    case policeCar

    // MARK: Interactive (moveable) obstacles
    case dog
    case human

    // MARK: - Properties

    /// Bounding size in game-world points.
    var size: CGSize {
        switch self {
        case .pothole:     return CGSize(width: 66,   height: 65)
        case .blackIce:    return CGSize(width: 66,   height: 65)
        case .cone:        return CGSize(width: 20,   height: 20)
        case .barricade:   return CGSize(width: 40,   height: 40)
        case .plant:       return CGSize(width: 101,  height: 100)
        case .textMessage: return CGSize(width: 40,   height: 80)
        case .movingCar:   return CGSize(width: 62.5, height: 125)
        case .ambulance:   return CGSize(width: 62.5, height: 125)
        case .policeCar:   return CGSize(width: 62.5, height: 125)
        case .dog:         return CGSize(width: 51,   height: 50)
        case .human:       return CGSize(width: 40,   height: 80)
        }
    }

    /// `true` for obstacles that respond to the player's horn and can flee.
    var isMoveable: Bool {
        self == .dog || self == .human
    }

    /// `true` for obstacles that produce a spin-out rather than a crash sound.
    var causesSpinOut: Bool {
        self == .pothole || self == .blackIce
    }
}
