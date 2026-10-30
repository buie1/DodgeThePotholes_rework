import SwiftUI

/// Legacy "drinking goggles": a black screen that pulses between 30% and fully
/// opaque every second while the booze power-down is active.
struct DrunkGogglesOverlay: View {
    var body: some View {
        Color.black
            .phaseAnimator([0.3, 1.0]) { content, opacity in
                content.opacity(opacity)
            } animation: { _ in
                .linear(duration: 1)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.green
        DrunkGogglesOverlay()
    }
}
