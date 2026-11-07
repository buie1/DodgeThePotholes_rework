import XCTest
@testable import DodgeThePotholes

/// Shop flow: confirm before buying; explain when an item is owned or unaffordable.
@MainActor
final class ShopViewModelTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var viewModel: ShopViewModel!

    override func setUp() async throws {
        try await super.setUp()
        persistence = MockPersistenceService()
        viewModel = ShopViewModel(persistence: persistence)
    }

    private func item(_ id: String) -> ShopItem {
        ShopItem.allItems.first { $0.id == id }!
    }

    func testAffordableItemAsksForConfirmation() {
        persistence.money = 600
        viewModel.select(item("redcar"))

        XCTAssertEqual(viewModel.pendingPurchase, item("redcar"))
        XCTAssertTrue(viewModel.isConfirmingPurchase)
        XCTAssertNil(viewModel.alert)
        XCTAssertEqual(persistence.money, 600, "Nothing is spent until confirmed")
    }

    func testConfirmingBuysTheItem() {
        persistence.money = 600
        viewModel.select(item("redcar"))
        viewModel.confirmPurchase()

        XCTAssertNil(viewModel.pendingPurchase)
        XCTAssertTrue(viewModel.isOwned(item("redcar")))
        XCTAssertEqual(viewModel.money, 600 - GameConfig.ShopCost.car)
    }

    func testCancellingSpendsNothing() {
        persistence.money = 600
        viewModel.select(item("redcar"))
        viewModel.isConfirmingPurchase = false

        XCTAssertNil(viewModel.pendingPurchase)
        XCTAssertFalse(viewModel.isOwned(item("redcar")))
        XCTAssertEqual(persistence.money, 600)
    }

    func testUnaffordableItemShowsInsufficientFunds() {
        persistence.money = 100
        viewModel.select(item("tank"))

        XCTAssertNil(viewModel.pendingPurchase)
        XCTAssertEqual(viewModel.alert?.title, "Insufficient Funds")
        XCTAssertEqual(viewModel.alert?.message, "This item costs $\(GameConfig.ShopCost.tank).")
    }

    func testOwnedItemShowsAlreadyPurchased() {
        persistence.money = 10_000
        persistence.unlocked = ["greencar"]
        viewModel.select(item("greencar"))

        XCTAssertNil(viewModel.pendingPurchase)
        XCTAssertEqual(viewModel.alert?.title, "Already Purchased")
        viewModel.isShowingAlert = false
        XCTAssertNil(viewModel.alert)
    }

    func testConfirmationWordingMatchesCategory() {
        XCTAssertEqual(ShopViewModel.confirmationMessage(for: item("tank")),
                       "Replace the monster truck with a tank?")
        XCTAssertEqual(ShopViewModel.confirmationMessage(for: item("catch_me.wav")),
                       "Buy Catch Me to play in-game?")
    }
}
