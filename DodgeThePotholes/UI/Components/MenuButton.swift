import SwiftUI

/// Full-width arcade button in the pixel font, used by the menus and game over screen.
struct MenuButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MenuButtonLabel(title: title, color: color)
        }
        .buttonStyle(.plain)
    }
}

/// The look of `MenuButton`, for wrapping in a `NavigationLink`.
struct MenuButtonLabel: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.pixel(13))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: color.opacity(0.5), radius: 8, y: 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        MenuButton(title: "NEW GAME", color: .yellow) {}
        MenuButton(title: "SETTINGS", color: .gray) {}
    }
    .padding(32)
    .background(.black)
}
