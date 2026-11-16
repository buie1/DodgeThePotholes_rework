import SwiftUI

/// First launch: "How do you want to steer?" with an animated preview of each choice.
/// Either can be changed later in Settings > Controls.
struct ControlChoiceView: View {

    let isTiltAvailable: Bool
    let onChoose: (ControlScheme) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RoadStripes()

            VStack(spacing: 28) {
                Text("HOW DO YOU\nWANT TO STEER?")
                    .font(.pixel(18).weight(.bold))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                    .shadow(color: .yellow.opacity(0.6), radius: 12)

                choice(.tilt) { TiltPreview() }
                choice(.drag) { DragPreview() }

                Text(isTiltAvailable ? "YOU CAN CHANGE THIS IN SETTINGS" : "TILT NEEDS A REAL DEVICE")
                    .font(.pixel(7))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 28)
        }
    }

    private func choice(_ scheme: ControlScheme, @ViewBuilder preview: () -> some View) -> some View {
        Button { onChoose(scheme) } label: {
            HStack(spacing: 18) {
                preview()
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 8) {
                    Text(scheme.title)
                        .font(.pixel(14))
                        .foregroundStyle(.yellow)
                    Text(scheme.summary)
                        .font(.pixel(7))
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("choose.\(scheme.rawValue)")
    }
}

/// A phone rocking left and right.
private struct TiltPreview: View {
    var body: some View {
        Image(systemName: "iphone")
            .font(.system(size: 44))
            .foregroundStyle(.white)
            .phaseAnimator([-18.0, 18.0]) { phone, angle in
                phone.rotationEffect(.degrees(angle))
            } animation: { _ in .easeInOut(duration: 0.9) }
    }
}

/// A finger sliding left and right.
private struct DragPreview: View {
    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 36))
            .foregroundStyle(.white)
            .phaseAnimator([-16.0, 16.0]) { finger, offset in
                finger.offset(x: offset)
            } animation: { _ in .easeInOut(duration: 0.9) }
    }
}

#Preview {
    ControlChoiceView(isTiltAvailable: true) { _ in }
}
