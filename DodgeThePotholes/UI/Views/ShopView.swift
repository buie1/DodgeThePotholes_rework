import SwiftUI

/// Spend banked money on cars, an extra life, the tank and songs.
/// Replaces the legacy `ShopScene`.
struct ShopView: View {

    @Bindable var viewModel: ShopViewModel

    var body: some View {
        MenuScreen("SHOP", titleColor: .green) {
            VStack(spacing: 20) {
                bank

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.items) { item in
                            ShopItemRow(item: item,
                                        isOwned: viewModel.isOwned(item),
                                        canAfford: viewModel.canAfford(item)) {
                                viewModel.select(item)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .confirmationDialog(
            viewModel.pendingPurchase.map { "Buy \($0.displayName)?" } ?? "",
            isPresented: $viewModel.isConfirmingPurchase,
            titleVisibility: .visible,
            presenting: viewModel.pendingPurchase
        ) { item in
            Button("Buy for $\(item.cost)") { viewModel.confirmPurchase() }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(ShopViewModel.confirmationMessage(for: item))
        }
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: $viewModel.isShowingAlert,
            presenting: viewModel.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    /// The player's banked money.
    private var bank: some View {
        HStack(spacing: 10) {
            SpriteImage(.dollar)
                .frame(height: 24)
            Text("\(viewModel.money)")
                .font(.pixel(16))
                .foregroundStyle(.green)
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.money)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bank: $\(viewModel.money)")
    }
}

#Preview {
    NavigationStack {
        ShopView(viewModel: ShopViewModel(persistence: SwiftDataPersistenceService.inMemory()))
    }
}
