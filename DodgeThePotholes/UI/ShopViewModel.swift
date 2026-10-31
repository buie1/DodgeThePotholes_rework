import Foundation
import Observation

/// A message the shop shows when a purchase can't go ahead.
struct ShopAlert: Equatable {
    let title: String
    let message: String
}

/// `@Observable` state for the Shop screen.
///
/// Tapping an item asks for confirmation via `pendingPurchase`; items the player
/// already owns or can't afford raise an `alert` instead (legacy `Alerts.swift`).
@Observable
@MainActor
final class ShopViewModel {

    /// Everything for sale, in display order.
    let items: [ShopItem] = ShopItem.allItems

    /// The item awaiting the player's confirmation; drives the confirmation dialog.
    var pendingPurchase: ShopItem?

    /// The current "already owned" / "insufficient funds" message, if any.
    var alert: ShopAlert?

    private let persistence: any PersistenceServiceProtocol

    init(persistence: any PersistenceServiceProtocol) {
        self.persistence = persistence
    }

    /// Banked money available to spend.
    var money: Int { persistence.money }

    /// Owned, or for the extra life, bought and waiting for the next run.
    func isOwned(_ item: ShopItem) -> Bool { persistence.isUnlocked(item) }

    func canAfford(_ item: ShopItem) -> Bool { money >= item.cost }

    // MARK: - Presentation bindings

    var isConfirmingPurchase: Bool {
        get { pendingPurchase != nil }
        set { if !newValue { pendingPurchase = nil } }
    }

    var isShowingAlert: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    // MARK: - Purchase flow

    /// Starts buying `item`: asks for confirmation, or explains why it can't be bought.
    func select(_ item: ShopItem) {
        if isOwned(item) {
            alert = Self.makeAlert(for: .alreadyOwned, item: item)
        } else if !canAfford(item) {
            alert = Self.makeAlert(for: .insufficientFunds, item: item)
        } else {
            pendingPurchase = item
        }
    }

    /// Buys the pending item.
    func confirmPurchase() {
        guard let item = pendingPurchase else { return }
        pendingPurchase = nil
        let result = persistence.purchase(item)
        if result != .purchased {
            alert = Self.makeAlert(for: result, item: item)
        }
    }

    /// The confirmation question for `item`, worded like the legacy prompts.
    static func confirmationMessage(for item: ShopItem) -> String {
        switch item.category {
        case .carSkin:        return "Do you want to buy the \(item.displayName)?"
        case .extraLife:      return "Start your next game with an extra life?"
        case .vehicleUpgrade: return "Replace the monster truck with a tank?"
        case .song:           return "Buy \(item.displayName) to play in-game?"
        }
    }

    private static func makeAlert(for result: PurchaseResult, item: ShopItem) -> ShopAlert? {
        switch result {
        case .purchased:
            return nil
        case .alreadyOwned:
            let message = item.category == .extraLife
                ? "Your extra life is waiting for your next game."
                : "You already own \(item.displayName)."
            return ShopAlert(title: "Already Purchased", message: message)
        case .insufficientFunds:
            return ShopAlert(title: "Insufficient Funds", message: "This item costs $\(item.cost).")
        }
    }
}
