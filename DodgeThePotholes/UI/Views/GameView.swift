import SwiftUI

/// Full-screen game canvas presented while `route == .playing` or `.gameOver`.
///
/// Rendering pipeline:
///   `TimelineView` fires at ≈60 fps → `Canvas` draws all entities using a
///   world-to-canvas coordinate transform (origin at centre, Y-up).
///
/// Input: `DragGesture(minimumDistance: 0)` maps horizontal translation to
///   a normalised [-1, 1] value forwarded to `GameViewModel`.
struct GameView: View {

    @Bindable var viewModel: GameViewModel

    // Track whether the engine has been started for this presentation.
    @State private var hasStarted = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                gameCanvas(geo: geo)

                HUDOverlay(viewModel: viewModel)

                if viewModel.isDrunkMode {
                    drunkOverlay
                }

                if let idx = viewModel.textMessageIndex {
                    TextMessageOverlay(index: idx)
                }

                if viewModel.route == .gameOver {
                    GameOverView(viewModel: viewModel, worldSize: geo.size)
                }
            }
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                viewModel.startGame(worldSize: geo.size)
            }
            .onChange(of: viewModel.route) { _, newRoute in
                // When Play Again resets route to .playing, re-enable the start guard.
                if newRoute == .playing && viewModel.engine != nil {
                    hasStarted = true   // engine already created by startGame; don't double-start
                }
            }
            .gesture(steeringGesture(width: geo.size.width))
            .ignoresSafeArea()
        }
    }

    // MARK: - Canvas

    /// Returns the game canvas view driven by a 60fps `TimelineView`.
    /// All drawing is delegated to `drawScene(ctx:size:)` to keep the
    /// Canvas renderer closure minimal and avoid nested-function type-inference issues.
    private func gameCanvas(geo: GeometryProxy) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { _ in
            Canvas { ctx, size in
                self.drawScene(ctx: &ctx, size: size)
            }
        }
    }

    // MARK: - Scene drawing

    /// Full scene renderer. Called by the Canvas on every timeline tick.
    /// Takes `ctx` as `inout` so all drawing commands accumulate on the same context.
    private func drawScene(ctx: inout GraphicsContext, size: CGSize) {
        guard let engine = viewModel.engine else { return }

        let w = size.width
        let h = size.height

        // World → canvas coordinate transform (origin at centre, Y-up).
        let cx: (CGFloat) -> CGFloat = { w / 2 + $0 }
        let cy: (CGFloat) -> CGFloat = { h / 2 - $0 }

        // -- Road background --
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h)),
            with: .color(.init(white: 0.13))
        )
        drawRoadMarkings(ctx: &ctx, size: size)

        // -- Coins --
        for coin in engine.coins where !coin.isCollected {
            let r = CGRect(
                x: cx(coin.position.x) - coin.size.width  / 2,
                y: cy(coin.position.y) - coin.size.height / 2,
                width: coin.size.width, height: coin.size.height
            )
            ctx.fill(Path(ellipseIn: r), with: .color(.yellow))
        }

        // -- Power-up pickups --
        for pu in engine.powerUpEntities where !pu.isCollected {
            let r = CGRect(
                x: cx(pu.position.x) - pu.size.width  / 2,
                y: cy(pu.position.y) - pu.size.height / 2,
                width: pu.size.width, height: pu.size.height
            )
            ctx.fill(Path(ellipseIn: r), with: .color(powerUpColor(pu.type)))
        }

        // -- Obstacles --
        for obs in engine.obstacles where !obs.isRemoved {
            let r = CGRect(
                x: cx(obs.position.x) - obs.size.width  / 2,
                y: cy(obs.position.y) - obs.size.height / 2,
                width: obs.size.width, height: obs.size.height
            )
            ctx.fill(
                RoundedRectangle(cornerRadius: 4).path(in: r),
                with: .color(obstacleColor(obs.type))
            )
        }

        // -- Player --
        let player = engine.player
        let pr = CGRect(
            x: cx(player.position.x) - player.size.width  / 2,
            y: cy(player.position.y) - player.size.height / 2,
            width: player.size.width, height: player.size.height
        )
        let playerColor: Color = player.state == .recovering  ? .white.opacity(0.4)
                               : player.state == .monsterTruck ? .orange
                               : .cyan
        ctx.fill(
            RoundedRectangle(cornerRadius: 6).path(in: pr),
            with: .color(playerColor)
        )
    }

    // MARK: - Road markings

    private func drawRoadMarkings(ctx: inout GraphicsContext, size: CGSize) {
        let laneCount = 4
        let laneWidth = size.width / CGFloat(laneCount)
        var path = Path()
        for i in 1..<laneCount {
            let x = laneWidth * CGFloat(i)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1.5)
    }

    // MARK: - Steering gesture

    private func steeringGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let norm = Double(value.translation.width) / Double(width / 2)
                viewModel.setHorizontalInput(max(-1, min(1, norm)))
            }
            .onEnded { _ in
                viewModel.stopHorizontalInput()
            }
    }

    // MARK: - Drunk overlay

    private var drunkOverlay: some View {
        Color.green
            .opacity(0.18)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Color helpers

    private func obstacleColor(_ type: ObstacleType) -> Color {
        switch type {
        case .pothole:     return .init(white: 0.25)
        case .blackIce:    return .blue.opacity(0.7)
        case .cone:        return .orange
        case .barricade:   return .red
        case .plant:       return .green
        case .textMessage: return .purple
        case .movingCar:   return .teal
        case .ambulance:   return .white
        case .policeCar:   return .blue
        case .dog:         return .brown
        case .human:       return .mint
        }
    }

    private func powerUpColor(_ type: PowerUpType) -> Color {
        switch type {
        case .wrap:              return .cyan
        case .multiplier:        return .yellow
        case .monsterTruck:      return .orange
        case .booze:             return .green
        case .oneUp:             return .pink
        }
    }
}

// MARK: - HUD Overlay

private struct HUDOverlay: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                // Score — top-left
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(viewModel.score)")
                        .font(.custom("Press Start 2P", size: 14))
                        .foregroundStyle(.white)
                }

                Spacer()

                // High score — top-centre
                VStack(spacing: 2) {
                    Text("BEST")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(viewModel.highScore)")
                        .font(.custom("Press Start 2P", size: 14))
                        .foregroundStyle(.yellow)
                }

                Spacer()

                // Lives — top-right
                VStack(alignment: .trailing, spacing: 2) {
                    Text("LIVES")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 4) {
                        ForEach(0..<max(0, viewModel.lives), id: \.self) { _ in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Active power-up timer bar
            if let pu = viewModel.activePowerUp {
                PowerUpTimerBar(state: pu)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            Spacer()

            // Money counter — bottom
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(viewModel.money)")
                    .font(.custom("Press Start 2P", size: 11))
                    .foregroundStyle(.yellow)
            }
            .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Power-up timer bar

private struct PowerUpTimerBar: View {
    let state: PowerUpState

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: geo.size.width * state.progress, height: 6)
                    .animation(.linear(duration: 0.1), value: state.progress)
            }
        }
        .frame(height: 6)
    }

    private var barColor: Color {
        switch state.type {
        case .monsterTruck: return .orange
        case .multiplier:   return .yellow
        case .wrap:         return .cyan
        case .booze:        return .green
        case .oneUp:        return .pink
        }
    }
}

// MARK: - Text message overlay

private struct TextMessageOverlay: View {
    let index: Int

    private let messages = [
        "📱 INCOMING TEXT!",
        "Never gonna give you up…",
        "Mom: Are you driving?!",
        "🚨 ROAD RAGE ALERT 🚨",
        "Check your notifications!"
    ]

    var body: some View {
        VStack {
            Spacer()
            Text(messages[index % messages.count])
                .font(.custom("Press Start 2P", size: 11))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 8)
                .padding(.bottom, 60)
        }
        .allowsHitTesting(false)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.3), value: index)
    }
}

#Preview {
    GameView(viewModel: {
        let vm = GameViewModel()
        return vm
    }())
}
