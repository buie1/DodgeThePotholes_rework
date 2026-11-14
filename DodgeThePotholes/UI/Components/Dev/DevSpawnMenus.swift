#if DEBUG
import SwiftUI

/// DEV panel menus: spawn an obstacle or power-up roll now, or start a power-up.
/// Debug builds only.
struct DevSpawnMenus: View {

    let viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ObstacleSpawn.devChoices, id: \.self) { spawn in
                    Button(spawn.devName) { viewModel.devAdjust { $0.spawnNow(spawn) } }
                }
            } label: {
                label("Obstacle")
            }

            Menu {
                ForEach(PowerUpSpawn.devChoices.filter { $0 != .nothing }, id: \.self) { spawn in
                    Button(spawn.devName) { viewModel.devAdjust { $0.spawnNow(spawn) } }
                }
            } label: {
                label("Pickup")
            }

            Menu {
                ForEach(PowerUpType.devChoices, id: \.self) { type in
                    Button(type.devName) { viewModel.devAdjust { $0.activatePowerUp(type) } }
                }
            } label: {
                label("Activate")
            }
        }
    }

    private func label(_ title: String) -> some View {
        Text("\(title) ▾")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.6), in: Capsule())
            .foregroundStyle(.white)
    }
}
#endif
