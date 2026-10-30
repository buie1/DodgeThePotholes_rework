import SwiftUI

/// Screens pushed from the main menu.
enum MenuDestination: Hashable {
    case settings
    case audio
}

/// Entry point the player sees on launch.
/// Owns `GameViewModel` and presents `GameView` as a full-screen cover
/// when a session starts. Settings and other menus push onto a `NavigationStack`.
struct MainMenuView: View {

    /// Saved player progress, injected by the app.
    let persistence: any PersistenceServiceProtocol

    @State private var viewModel: GameViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(persistence: any PersistenceServiceProtocol) {
        self.persistence = persistence
        _viewModel = State(initialValue: GameViewModel(persistence: persistence))
        _settingsViewModel = State(initialValue: SettingsViewModel(persistence: persistence))
    }

    var body: some View {
        NavigationStack {
            menu
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MenuDestination.self, destination: destination)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingGame) {
            GameView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func destination(_ screen: MenuDestination) -> some View {
        switch screen {
        case .settings: SettingsView()
        case .audio:    AudioSettingsView(viewModel: settingsViewModel)
        }
    }

    // MARK: - Sub-views

    private var menu: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            roadStripes

            VStack(spacing: 32) {
                Spacer()
                titleBlock
                Spacer()
                buttonStack
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("DODGE THE")
                .font(.pixel(22).weight(.bold))
                .foregroundStyle(.white)
            Text("POTHOLES")
                .font(.pixel(22).weight(.bold))
                .foregroundStyle(.yellow)
        }
        .multilineTextAlignment(.center)
        .shadow(color: .yellow.opacity(0.6), radius: 12)
    }

    private var buttonStack: some View {
        VStack(spacing: 16) {
            MenuButton(title: "NEW GAME", color: .yellow) {
                viewModel.navigateToGame()
            }
            MenuButton(title: "LEADERBOARD", color: .cyan)  { /* Phase 5 */ }
            MenuButton(title: "SHOP",        color: .green) { /* Step 5 */ }
            NavigationLink(value: MenuDestination.settings) {
                MenuButtonLabel(title: "SETTINGS", color: .gray)
            }
            .buttonStyle(.plain)
        }
    }

    /// Decorative vertical road stripes in the background.
    private var roadStripes: some View {
        GeometryReader { geo in
            let stripeCount = 5
            let w = geo.size.width / CGFloat(stripeCount + 1)
            HStack(spacing: w - 3) {
                ForEach(0..<stripeCount, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MainMenuView(persistence: SwiftDataPersistenceService.inMemory())
}
