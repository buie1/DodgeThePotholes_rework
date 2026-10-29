import SpriteKit

/// Typed names for every sprite in `Resources/Assets.xcassets`, plus texture loading.
///
/// The legacy art is 1x pixel art, so every texture is configured with
/// `.nearest` filtering to stay crisp when scaled up.
enum SpriteCatalog {

    // MARK: - Single images

    /// Stand-alone image sets used by gameplay and the HUD.
    enum Image: String, CaseIterable {
        // Player / vehicles
        case car1, car2, car3, tank
        case monsterTruck = "MonsterTruck"
        case taxi, truck, sedan
        // Road & environment
        case road, roadLong = "road_long"
        case tree1, bush1
        // Obstacles
        case pothole1, pothole2, pothole3
        case ice, cone, barricade, phone
        case dogDefault = "Shepherd_default-1"
        case dogDead    = "German_Shepherd_Dead"
        // Power-ups & collectibles
        case beer, dollar, oneup, star
        case powWrap = "pow_wrap"
        case powX2   = "pow_x2"
        case powX3   = "pow_x3"
        // Horn / missile / HUD
        case carHorn, missle, alert, wheel
        // Particles
        case spark, bokeh
    }

    // MARK: - Animations

    /// Multi-frame sprite atlases, with the legacy frame-naming scheme.
    enum Animation: CaseIterable {
        case ambulance, police
        case dogRun, dogWalk, dogBark
        case oldManWalk, oldManJump, oldManDead
        case buffGuyWalk, buffGuyJump
        case taxiLeft, taxiRight, truckLeft, truckRight, sedanLeft, sedanRight
        case car1Left, car1Right, car2Left, car2Right, car3Left, car3Right

        /// Ordered frame image names inside the atlas.
        var frameNames: [String] {
            switch self {
            case .ambulance:   return (1...4).map { "ambulance_\($0)" }
            case .police:      return (1...4).map { "police_0\($0)" }
            case .dogRun:      return (1...5).map { "Shepherd_run_\($0)" }
            case .dogWalk:     return (1...6).map { "Shepherd_walk_\($0)" }
            case .dogBark:     return (1...3).map { "Shepherd_bark_\($0)" }
            case .oldManWalk:  return (0...3).map { "old_man_walk_\($0)" }
            case .oldManJump:  return (0...9).map { "old_man_jump_\($0)" }
            case .oldManDead:  return (0...3).map { "old_man_dead_\($0)" }
            case .buffGuyWalk: return (0...3).map { "buff_guy_walk_\($0)" }
            case .buffGuyJump: return (0...2).map { "buff_guy_jump_\($0)" }
            case .taxiLeft:    return (0...1).map { "taxi_left_\($0)" }
            case .taxiRight:   return (0...1).map { "taxi_right_\($0)" }
            case .truckLeft:   return (0...1).map { "truck_left_\($0)" }
            case .truckRight:  return (0...1).map { "truck_right_\($0)" }
            case .sedanLeft:   return (0...1).map { "sedan_left_\($0)" }
            case .sedanRight:  return (0...1).map { "sedan_right_\($0)" }
            case .car1Left:    return (1...2).map { "car1_left_\($0)" }
            case .car1Right:   return (1...2).map { "car1_right_\($0)" }
            case .car2Left:    return (1...2).map { "car2_left_\($0)" }
            case .car2Right:   return (1...2).map { "car2_right_\($0)" }
            case .car3Left:    return (1...2).map { "car3_left_\($0)" }
            case .car3Right:   return (1...2).map { "car3_right_\($0)" }
            }
        }
    }

    /// Every image name the catalog can load (single images + animation frames).
    static var allImageNames: [String] {
        Image.allCases.map(\.rawValue) + Animation.allCases.flatMap(\.frameNames)
    }

    // MARK: - Texture loading

    /// Returns a pixel-art texture for a single image.
    static func texture(_ image: Image) -> SKTexture {
        texture(named: image.rawValue)
    }

    /// Returns the ordered pixel-art textures for an animation.
    static func frames(_ animation: Animation) -> [SKTexture] {
        animation.frameNames.map(texture(named:))
    }

    /// Preloads every texture into GPU memory before gameplay starts.
    static func preload() async {
        await SKTexture.preload(allImageNames.map(texture(named:)))
    }

    private static func texture(named name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }
}
