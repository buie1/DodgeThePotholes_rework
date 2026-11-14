import SwiftUI

/// One item for sale: its picture, name, and price or owned state.
struct ShopItemRow: View {
    let item: ShopItem
    let isOwned: Bool
    let canAfford: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(item.imageName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                Text(item.displayName.uppercased())
                    .font(.pixel(9))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text(status)
                    .font(.pixel(9))
                    .foregroundStyle(statusColor)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.displayName), \(isOwned ? status.lowercased() : "$\(item.cost)")")
    }

    private var status: String {
        guard isOwned else { return "$\(item.cost)" }
        return item.category == .extraLife ? "READY" : "OWNED"
    }

    private var statusColor: Color {
        if isOwned { return .green }
        return canAfford ? .yellow : .red.opacity(0.8)
    }
}

#Preview {
    VStack(spacing: 10) {
        let items = GameCatalog.bundled.shopItems
        ShopItemRow(item: items[0], isOwned: true, canAfford: true) {}
        ShopItemRow(item: items[2], isOwned: false, canAfford: true) {}
        ShopItemRow(item: items[3], isOwned: false, canAfford: false) {}
    }
    .padding()
    .background(.black)
}
