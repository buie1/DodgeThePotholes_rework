import SwiftUI

/// Choose Tilt or Drag steering, and calibrate tilt to how you hold the phone.
struct ControlsSettingsView: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        MenuScreen("CONTROLS", titleColor: .green) {
            VStack(spacing: 20) {
                ControlSchemeCard(scheme: .tilt, isSelected: viewModel.controlScheme == .tilt) {
                    viewModel.controlScheme = .tilt
                }
                ControlSchemeCard(scheme: .drag, isSelected: viewModel.controlScheme == .drag) {
                    viewModel.controlScheme = .drag
                }

                if viewModel.controlScheme == .tilt {
                    calibration
                }

                MenuButton(title: "REPLAY TUTORIAL", color: .gray, action: viewModel.replayTutorial)
                if viewModel.isTutorialQueued {
                    Text("PLAYS ON YOUR NEXT GAME")
                        .font(.pixel(7))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .onAppear(perform: viewModel.startTiltPreview)
        .onDisappear(perform: viewModel.stopTiltPreview)
    }

    @ViewBuilder
    private var calibration: some View {
        if viewModel.isTiltAvailable {
            VStack(spacing: 12) {
                TiltMeter(value: viewModel.tiltPreview)
                Text("HOLD THE PHONE HOW YOU LIKE TO PLAY, THEN CALIBRATE")
                    .font(.pixel(7))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                MenuButton(title: "CALIBRATE", color: .cyan, action: viewModel.calibrateTilt)
                if viewModel.isTiltCalibrated {
                    Button(action: viewModel.resetTiltCalibration) {
                        Text("RESET CALIBRATION")
                            .font(.pixel(8))
                            .foregroundStyle(.yellow)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        } else {
            Text("TILT NEEDS A REAL DEVICE. DRAG WORKS EVERYWHERE.")
                .font(.pixel(7))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

/// One steering choice: its name, how it works, and whether it's selected.
struct ControlSchemeCard: View {
    let scheme: ControlScheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(scheme.title)
                    .font(.pixel(12))
                    .foregroundStyle(isSelected ? .yellow : .white)
                Text(scheme.summary)
                    .font(.pixel(7))
                    .lineSpacing(5)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(isSelected ? 0.12 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.yellow : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("controls.\(scheme.rawValue)")
        .accessibilityValue(isSelected ? "selected" : "")
    }
}

/// Live tilt: a marker that moves left and right as the phone leans.
private struct TiltMeter: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Capsule().fill(Color.white.opacity(0.15))
                Rectangle().fill(Color.white.opacity(0.4)).frame(width: 2)
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 16, height: 16)
                    .offset(x: value * (geo.size.width / 2 - 8))
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

extension ControlScheme {
    var title: String {
        switch self {
        case .tilt: return "TILT"
        case .drag: return "DRAG"
        }
    }

    var summary: String {
        switch self {
        case .tilt: return "LEAN THE PHONE TO STEER. YOU CAN STILL DRAG A FINGER TO OVERRIDE."
        case .drag: return "DRAG A FINGER LEFT AND RIGHT TO STEER. TILT IS OFF."
        }
    }
}

#Preview {
    NavigationStack {
        ControlsSettingsView(viewModel: SettingsViewModel(persistence: SwiftDataPersistenceService.inMemory()))
    }
}
