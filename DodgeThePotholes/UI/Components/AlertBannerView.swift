import SwiftUI

/// Red warning text that flies in from the right and out to the left (legacy `flyInFunction`).
/// A traffic-zone warning also flashes the alert sign at the top of the screen.
/// Insert and remove it with animation to play the fly-through.
struct AlertBannerView: View {
    let alert: GameAlert

    var body: some View {
        ZStack {
            if alert == .trafficZone {
                VStack {
                    SpriteImage(.alert)
                        .frame(width: 72)
                        .phaseAnimator([1.0, 0.0]) { content, opacity in
                            content.opacity(opacity)
                        } animation: { _ in
                            .linear(duration: 0.3)
                        }
                        .padding(.top, 96)
                    Spacer()
                }
            }

            Text(alert.message)
                .font(.pixel(15))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .padding(.horizontal, 16)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)))
        .allowsHitTesting(false)
    }
}

#Preview {
    AlertBannerView(alert: .trafficZone)
        .background(.gray)
}
