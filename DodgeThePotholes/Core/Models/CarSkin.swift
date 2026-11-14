import Foundation

/// A player car from `GameCatalog`: its sprite, turn-signal frames and unlock.
///
/// The tank is not a skin: owning it replaces the monster-truck power-up sprite.
struct CarSkin: Decodable, Hashable, Identifiable {
    /// Saved in `PlayerProfile.selectedCarKey`; legacy values are `car1`–`car3`.
    let id: String
    /// Human-readable name for the shop / car-select screen.
    let displayName: String
    /// Asset catalog image of the car driving straight.
    let imageName: String
    /// Blinker frames shown while steering left.
    let leftFrames: [String]
    /// Blinker frames shown while steering right.
    let rightFrames: [String]
    /// `ShopItem.id` that unlocks this car; `nil` for a free car.
    let unlockKey: String?

    private enum CodingKeys: String, CodingKey {
        case id, leftFrames, rightFrames, unlockKey
        case displayName = "name"
        case imageName = "sprite"
    }

    /// Every image the car can show.
    var imageNames: [String] { [imageName] + leftFrames + rightFrames }
}
