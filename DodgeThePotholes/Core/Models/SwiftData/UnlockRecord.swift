import Foundation
import SwiftData

/// A permanent shop purchase: a car, a song, or the tank.
@Model
final class UnlockRecord {
    /// `ShopItem.id`: "redcar" | "greencar" | "tank" | a song filename.
    var itemKey: String
    var isPurchased: Bool
    var purchasedDate: Date?

    init(itemKey: String, isPurchased: Bool = true, purchasedDate: Date? = .now) {
        self.itemKey = itemKey
        self.isPurchased = isPurchased
        self.purchasedDate = purchasedDate
    }
}
