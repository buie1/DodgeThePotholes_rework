import SwiftUI

/// The tutorial's instruction for the current step, with a Skip button, and the
/// "You're ready!" panel that starts the real run. Shows nothing outside the tutorial.
struct TutorialOverlayView: View {
    let viewModel: GameViewModel

    var body: some View {
        if let tutorial = viewModel.tutorial {
            if tutorial.step == .done {
                ready
            } else {
                prompt(tutorial)
            }
        }
    }

    private func prompt(_ tutorial: Tutorial) -> some View {
        VStack(spacing: 12) {
            Text("STEP \(tutorial.progress + 1) OF 4")
                .font(.pixel(8))
                .foregroundStyle(.white.opacity(0.7))
            Text(tutorial.prompt)
                .font(.pixel(12))
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .shadow(color: .black, radius: 4)
                .accessibilityIdentifier("tutorial.prompt")
            // A full-size tap target, though the label is small.
            Button(action: viewModel.finishTutorial) {
                Text("SKIP TUTORIAL")
                    .font(.pixel(8))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .contentShape(Capsule())
            }
            .accessibilityIdentifier("tutorial.skip")
        }
        .padding(.horizontal, 32)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 150)
        .animation(.easeInOut, value: tutorial.step)
    }

    private var ready: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("YOU'RE READY!")
                    .font(.pixel(22).weight(.bold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 12)
                Text("DODGE THE POTHOLES.\nCLOSE CALLS BUILD YOUR COMBO.")
                    .font(.pixel(8))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                MenuButton(title: "START RUN", color: .yellow, action: viewModel.finishTutorial)
                    .padding(.horizontal, 32)
            }
        }
    }
}
