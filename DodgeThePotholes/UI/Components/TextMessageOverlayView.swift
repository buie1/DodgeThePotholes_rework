import SwiftUI

/// The rickroll "New Text Message" notification shown when the player hits a phone.
/// Legacy showed a blocking action sheet; this slides up from the bottom and
/// auto-dismisses (see `GameViewModel`) without pausing play.
struct TextMessageOverlayView: View {
    let index: Int

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SpriteImage(.phone)
                        .frame(width: 18, height: 18)
                    Text("NEW TEXT MESSAGE")
                        .font(.pixel(8))
                        .foregroundStyle(.secondary)
                }
                Text(TextMessageLyrics.line(at: index))
                    .font(.pixel(11))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.gray
        TextMessageOverlayView(index: 6)
    }
}
