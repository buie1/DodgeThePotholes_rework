import SwiftUI

/// The combo under the score: the multiplier, pips toward the next level, and a bar
/// that drains as the combo's window runs out. Hidden while there is no combo.
struct ComboMeterView: View {
    let combo: Combo

    var body: some View {
        if combo.isActive {
            HStack(spacing: 8) {
                Text("x\(combo.multiplier)")
                    .font(.pixel(14))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.7), radius: 6)
                    .keyframeAnimator(initialValue: 1.0, trigger: combo.multiplier) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.6, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.25)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    if !isMaxed {
                        pips
                    }
                    timerBar
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Combo times \(combo.multiplier)")
        }
    }

    private var isMaxed: Bool { combo.multiplier >= combo.rules.maxMultiplier }

    /// Actions so far toward the next level.
    private var pips: some View {
        let done = combo.chain % combo.rules.actionsPerLevel
        return HStack(spacing: 3) {
            ForEach(0..<combo.rules.actionsPerLevel, id: \.self) { index in
                Rectangle()
                    .fill(index < done ? color : Color.white.opacity(0.25))
                    .frame(width: 8, height: 4)
            }
        }
    }

    private var timerBar: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.2))
            Rectangle()
                .fill(color)
                .frame(width: 48 * max(0, combo.timeLeft / combo.rules.window))
        }
        .frame(width: 48, height: 4)
    }

    /// White at x1, warming through yellow and orange to red and magenta at x5.
    private var color: Color {
        switch combo.multiplier {
        case 1:  return .white
        case 2:  return .yellow
        case 3:  return .orange
        case 4:  return .red
        default: return .pink
        }
    }
}

#Preview {
    var combo = Combo(rules: GameTuning.bundled.combo)
    combo.add(actions: 4)
    return ComboMeterView(combo: combo)
        .padding()
        .background(.black)
}
