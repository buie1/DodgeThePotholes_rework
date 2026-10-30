import SwiftUI

/// Remaining lives as a row of tyres, like the legacy HUD.
struct LivesDisplayView: View {
    let lives: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(0, lives), id: \.self) { _ in
                SpriteImage(.wheel)
                    .frame(width: 20, height: 20)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(lives) lives")
    }
}

#Preview {
    LivesDisplayView(lives: 3)
        .padding()
        .background(.black)
}
