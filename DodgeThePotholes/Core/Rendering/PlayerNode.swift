import SpriteKit

/// The player's car sprite: skin texture, monster-truck swap, recovery flash,
/// spin-out, and turn-signal blinkers while steering.
@MainActor
final class PlayerNode: SKSpriteNode {

    private enum ActionKey {
        static let flash  = "flash"
        static let signal = "signal"
    }

    private enum Signal { case none, left, right }

    private let factory: EntityNodeFactory
    private var isShowingMonsterTruck = false
    private var signal: Signal = .none

    init(player: PlayerEntity, factory: EntityNodeFactory) {
        self.factory = factory
        super.init(texture: factory.texture(player.carSkin.imageName), color: .clear, size: player.size)
        zPosition = 2
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Mirrors the engine's player state onto the sprite. Call once per frame.
    func update(from player: PlayerEntity) {
        position = player.position
        size = player.size

        if player.isMonsterTruck != isShowingMonsterTruck {
            isShowingMonsterTruck = player.isMonsterTruck
            setSignal(.none, skin: player.carSkin)
            texture = factory.texture(player.isMonsterTruck
                ? SpriteCatalog.Image.monsterTruck.rawValue
                : player.carSkin.imageName)
        }
        if !player.isMonsterTruck {
            let dx = player.velocity.dx
            setSignal(dx > 1 ? .right : dx < -1 ? .left : .none, skin: player.carSkin)
        }
        updateFlash(isRecovering: player.isRecovering)
    }

    /// Legacy spin-out: two full turns in 0.75 s, ending upright.
    func spinOut() {
        run(.sequence([
            .rotate(byAngle: 4 * .pi, duration: 0.75),
            .run { [weak self] in self?.zRotation = 0 },
        ]))
    }

    // MARK: - Private

    /// Legacy recovery flash: fade out and back in every 0.6 s.
    private func updateFlash(isRecovering: Bool) {
        let isFlashing = action(forKey: ActionKey.flash) != nil
        if isRecovering && !isFlashing {
            run(.repeatForever(.sequence([.fadeOut(withDuration: 0.3), .fadeIn(withDuration: 0.3)])),
                withKey: ActionKey.flash)
        } else if !isRecovering && isFlashing {
            removeAction(forKey: ActionKey.flash)
            alpha = 1
        }
    }

    private func setSignal(_ newSignal: Signal, skin: CarSkin) {
        guard newSignal != signal else { return }
        signal = newSignal
        removeAction(forKey: ActionKey.signal)
        guard let animation = signalAnimation(newSignal, skin: skin) else {
            if !isShowingMonsterTruck { texture = factory.texture(skin.imageName) }
            return
        }
        run(.repeatForever(.animate(with: factory.frames(animation), timePerFrame: 0.2)),
            withKey: ActionKey.signal)
    }

    /// Blinker frames exist for the three car skins only.
    private func signalAnimation(_ signal: Signal, skin: CarSkin) -> SpriteCatalog.Animation? {
        switch (skin, signal) {
        case (.blue, .left):   return .car1Left
        case (.blue, .right):  return .car1Right
        case (.red, .left):    return .car2Left
        case (.red, .right):   return .car2Right
        case (.green, .left):  return .car3Left
        case (.green, .right): return .car3Right
        default:               return nil
        }
    }
}
