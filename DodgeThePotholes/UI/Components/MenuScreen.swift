import SwiftUI

/// Shared layout for screens pushed from the main menu: black background,
/// pixel-font title, and a dark navigation bar with a yellow back button.
struct MenuScreen<Content: View>: View {
    let title: String
    let titleColor: Color
    @ViewBuilder let content: Content

    init(_ title: String, titleColor: Color = .yellow, @ViewBuilder content: () -> Content) {
        self.title = title
        self.titleColor = titleColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Text(title)
                    .font(.pixel(20).weight(.bold))
                    .foregroundStyle(titleColor)
                    .shadow(color: titleColor.opacity(0.6), radius: 12)
                    .padding(.top, 24)

                content

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.yellow)
    }
}

#Preview {
    NavigationStack {
        MenuScreen("SETTINGS") {
            MenuButton(title: "AUDIO", color: .cyan) {}
        }
    }
}
