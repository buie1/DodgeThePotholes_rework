import Foundation

/// Categories of purchasable items in the shop.
enum ShopCategory: String, Decodable, Equatable {
    case carSkin
    case extraLife
    case vehicleUpgrade
    case song
}

/// A single purchasable item from `GameCatalog`.
struct ShopItem: Decodable, Identifiable, Equatable {
    let id: String               // Matches UnlockRecord.itemKey
    let displayName: String
    let cost: Int
    let imageName: String
    let category: ShopCategory

    private enum CodingKeys: String, CodingKey {
        case id, cost, category
        case displayName = "name"
        case imageName = "image"
    }
}
