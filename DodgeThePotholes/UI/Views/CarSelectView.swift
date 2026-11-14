import SwiftUI

/// Pick the car for the next run from the ones the player owns.
/// Replaces the legacy `CarScene`.
struct CarSelectView: View {

    let viewModel: SettingsViewModel

    var body: some View {
        MenuScreen("CAR", titleColor: .orange) {
            VStack(spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(viewModel.cars) { car in
                        CarCard(car: car,
                                isOwned: viewModel.isOwned(car),
                                isSelected: viewModel.selectedCar == car) {
                            viewModel.select(car)
                        }
                    }
                }

                Text("BUY LOCKED CARS IN THE SHOP")
                    .font(.pixel(7))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Car card

/// One car: its sprite, name, and selected / locked state.
private struct CarCard: View {
    let car: CarSkin
    let isOwned: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                SpriteImage(named: car.imageName)
                    .frame(height: 110)
                    .opacity(isOwned ? 1 : 0.3)

                Text(car.displayName.uppercased())
                    .font(.pixel(7))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)

                Text(status)
                    .font(.pixel(7))
                    .foregroundStyle(statusColor)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(isSelected ? 0.12 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.yellow : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isOwned)
        .accessibilityLabel("\(car.displayName), \(status.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var status: String {
        if isSelected { return "SELECTED" }
        return isOwned ? "OWNED" : "LOCKED"
    }

    private var statusColor: Color {
        if isSelected { return .yellow }
        return isOwned ? .green : .red
    }
}

#Preview {
    NavigationStack {
        CarSelectView(viewModel: SettingsViewModel(persistence: SwiftDataPersistenceService.inMemory()))
    }
}
