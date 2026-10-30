import Foundation

/// Categories of purchasable items in the shop.
enum ShopCategory: Equatable {
    case carSkin
    case extraLife
    case vehicleUpgrade
    case song
}

/// A single purchasable item.
struct ShopItem: Identifiable, Equatable {
    let id: String               // Matches UnlockRecord.itemKey
    let displayName: String
    let cost: Int
    let imageName: String
    let category: ShopCategory

    // MARK: - Predefined catalogue
    static let allItems: [ShopItem] = [
        ShopItem(id: "redcar",   displayName: "Red Rocket",    cost: GameConfig.ShopCost.car,  imageName: "car2",     category: .carSkin),
        ShopItem(id: "greencar", displayName: "Green Machine", cost: GameConfig.ShopCost.car,  imageName: "car3",     category: .carSkin),
        ShopItem(id: "life",     displayName: "Extra Life",    cost: GameConfig.ShopCost.life, imageName: "oneup",    category: .extraLife),
        ShopItem(id: "tank",     displayName: "Tank Upgrade",  cost: GameConfig.ShopCost.tank, imageName: "tank",     category: .vehicleUpgrade),
        ShopItem(id: "hot-pursuit.wav",  displayName: "Hot Pursuit",  cost: GameConfig.ShopCost.song, imageName: "music", category: .song),
        ShopItem(id: "born-lucky.wav",   displayName: "Born Lucky",   cost: GameConfig.ShopCost.song, imageName: "music", category: .song),
        ShopItem(id: "race_duel.wav",    displayName: "Race Duel",    cost: GameConfig.ShopCost.song, imageName: "music", category: .song),
        ShopItem(id: "catch_me.wav",     displayName: "Catch Me",     cost: GameConfig.ShopCost.song, imageName: "music", category: .song),
        ShopItem(id: "urban_chase.wav",  displayName: "Urban Chase",  cost: GameConfig.ShopCost.song, imageName: "music", category: .song),
    ]
}
