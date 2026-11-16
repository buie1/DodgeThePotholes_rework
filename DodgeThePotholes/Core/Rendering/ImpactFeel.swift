import SpriteKit

/// How hard one kind of hit lands on screen. Presentation only: the engine never
/// sees these, so they can be tuned freely without changing gameplay.
struct ImpactFeel {
    /// Peak camera offset in world units. The camera zooms in by the same amount so
    /// the shake never shows past the edge of the world.
    let shake: Double
    /// Seconds the shake takes to settle.
    let shakeDuration: Double
    /// Seconds the action freezes on contact ("hit-stop").
    let hitStop: Double
    /// Peak opacity of the red screen flash; `0` for none.
    let flash: Double

    /// Losing a life to a crash.
    static let crash = ImpactFeel(shake: 18, shakeDuration: 0.35, hitStop: 0.09, flash: 0.35)
    /// Losing a life to a spin-out on a pothole or black ice.
    static let spinOut = ImpactFeel(shake: 10, shakeDuration: 0.3, hitStop: 0.05, flash: 0.2)
    /// The monster truck or a missile blowing something up. No freeze, so rampages flow.
    static let explosion = ImpactFeel(shake: 8, shakeDuration: 0.2, hitStop: 0, flash: 0)
}

/// The scene's camera: shakes, flashes red and briefly holds the action on impacts.
@MainActor
final class ImpactCamera: SKCameraNode {

    private let worldWidth: Double
    private let flash: SKSpriteNode
    private var shakeAmplitude: Double = 0
    private var shakeDuration: Double = 0
    private var shakeRemaining: Double = 0
    private var hitStopRemaining: Double = 0

    init(worldSize: CGSize) {
        worldWidth = worldSize.width
        // A child of the camera, so the flash covers the screen and doesn't shake.
        flash = SKSpriteNode(color: .red, size: worldSize)
        super.init()
        flash.alpha = 0
        flash.zPosition = 20
        addChild(flash)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Starts `feel`'s shake, hit-stop and flash. A weaker shake never cuts off a stronger one.
    func impact(_ feel: ImpactFeel) {
        if feel.shake >= currentShake {
            shakeAmplitude = feel.shake
            shakeDuration = feel.shakeDuration
            shakeRemaining = feel.shakeDuration
        }
        hitStopRemaining = max(hitStopRemaining, feel.hitStop)
        if feel.flash > 0 {
            flash.removeAllActions()
            flash.alpha = feel.flash
            flash.run(.fadeOut(withDuration: 0.3))
        }
    }

    /// Counts down a hit-stop.
    /// - Returns: `true` while the action should stay frozen this frame.
    func holdsAction(for dt: Double) -> Bool {
        guard hitStopRemaining > 0 else { return false }
        hitStopRemaining -= dt
        return true
    }

    /// Jitters while a shake decays, zooming in just enough to hide the world's
    /// edges, then settles back. Call once per frame.
    func update(dt: Double) {
        guard shakeRemaining > 0 else {
            position = .zero
            setScale(1)
            return
        }
        shakeRemaining = max(0, shakeRemaining - dt)
        let amplitude = currentShake
        position = CGPoint(x: .random(in: -amplitude...amplitude), y: .random(in: -amplitude...amplitude))
        setScale(1 - 2 * amplitude / worldWidth)
    }

    /// The shake's amplitude now, decaying linearly to zero.
    private var currentShake: Double {
        shakeDuration > 0 ? shakeAmplitude * shakeRemaining / shakeDuration : 0
    }
}
