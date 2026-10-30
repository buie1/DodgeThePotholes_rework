import SwiftUI

/// The active power-up's icon, countdown label, and draining progress bar.
struct PowerUpTimerBar: View {
    let state: PowerUpState

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                SpriteImage(icon)
                    .frame(width: 22, height: 22)
            }
            Text("TIME 00:\(state.timerLabel)")
                .font(.pixel(9))
                .foregroundStyle(.yellow)
                .monospacedDigit()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * state.progress)
                        .animation(.linear(duration: 0.1), value: state.progress)
                }
            }
            .frame(height: 6)
        }
    }

    private var icon: SpriteCatalog.Image? {
        switch state.type {
        case .wrap:                  return .powWrap
        case .multiplier(let value): return value >= 3 ? .powX3 : .powX2
        case .monsterTruck:          return .star
        case .booze:                 return .beer
        case .oneUp:                 return nil
        }
    }

    private var barColor: Color {
        switch state.type {
        case .monsterTruck: return .orange
        case .multiplier:   return .yellow
        case .wrap:         return .cyan
        case .booze:        return .green
        case .oneUp:        return .pink
        }
    }
}

#Preview {
    PowerUpTimerBar(state: PowerUpState(type: .multiplier(2), remainingSeconds: 12, totalSeconds: 30))
        .padding()
        .background(.black)
}
