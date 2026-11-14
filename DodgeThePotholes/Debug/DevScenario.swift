#if DEBUG
import Foundation
import SwiftUI

/// A dev-mode setup that drops a run into an exact situation. Debug builds only.
///
/// Every field is optional, so an empty scenario is a normal run. Start one with the
/// `-devScenario <preset>` or `-devScenarioJSON '<json>'` launch argument
/// (see `docs/DEV_MODE.md`). Dev runs never submit to Game Center.
struct DevScenario {
    /// Seeds the spawners for a reproducible road; `nil` picks a random seed.
    var seed: UInt64?
    /// Replacement spawn pools. `nil` keeps the tuning's pool; `[]` spawns nothing.
    var obstacles: [(ObstacleSpawn, Int)]?
    var environment: [(EnvSpawnType, Int)]?
    var powerUps: [(PowerUpSpawn, Int)]?
    /// Starts the speed ramp as if this many seconds had been played.
    var startElapsed: Double?
    /// Power-ups active from the first frame.
    var startPowerUps: [PowerUpType] = []
    /// Starting lives (at least 1).
    var lives: Int?
    /// Hits flash the car but never cost a life.
    var godMode = false
    /// Simulation speed: `0.5` is slow motion, `2` is double speed.
    var timeScale: Double = 1
    /// A bot drives (see `Autopilot`), for unattended runs.
    var autopilot = false
    /// Outlines every hit box on screen.
    var hitboxes = false
    /// Bank balance for the throwaway profile.
    var bank: Int?
    /// Owns every shop item on the throwaway profile.
    var unlockAll = false
    /// Plays on the real saved profile instead of a throwaway one. Runs are then
    /// not recorded, so dev scores never touch real progress.
    var useRealProfile = false

    /// The spawn pools for this scenario, falling back to `base` for any not overridden.
    func spawnTables(base: SpawnTables) -> SpawnTables {
        SpawnTables(obstacles: obstacles ?? base.obstacles,
                    environment: environment ?? base.environment,
                    powerUps: powerUps ?? base.powerUps)
    }

    /// A fresh engine for one run of this scenario, and the seed it uses
    /// (`seed`, or a random one) so the road can be replayed.
    @MainActor
    func makeEngine(worldSize: CGSize, carSkin: CarSkin = GameCatalog.bundled.defaultCar,
                    tuning: GameTuning = .bundled) -> (engine: GameEngine, seed: UInt64) {
        let seed = seed ?? .random(in: .min ... .max)
        let engine = GameEngine(worldSize: worldSize, carSkin: carSkin, tuning: tuning,
                                tables: spawnTables(base: tuning.weights),
                                rng: SplitMix64(seed: seed), drivesOwnLoop: false)
        return (engine, seed)
    }

    /// Applies the in-run setup to a just-started engine.
    @MainActor
    func apply(to engine: GameEngine) {
        engine.debug.godMode = godMode
        engine.debug.timeScale = timeScale
        engine.debug.autopilot = autopilot ? Autopilot() : nil
        if let startElapsed { engine.fastForwardSpeedRamp(by: startElapsed) }
        if let lives { engine.setLives(lives) }
        startPowerUps.forEach(engine.activatePowerUp)
    }
}

// MARK: - Presets

extension DevScenario {
    /// Named setups for common checks, in menu order. All use seed 42 so a preset
    /// plays the same road every time.
    static let presets: [(name: String, scenario: DevScenario)] = [
        ("godCruise",    DevScenario(seed: 42, godMode: true)),
        ("monsterTruck", DevScenario(seed: 42, startPowerUps: [.monsterTruck], godMode: true)),
        ("potholeRain",  DevScenario(seed: 42, obstacles: [(.single(.pothole), 1)], godMode: true)),
        ("lateGame",     DevScenario(seed: 42, startElapsed: 170)),
        ("coinShower",   DevScenario(seed: 42, environment: [(.coinPattern, 1)], startPowerUps: [.multiplier(3)])),
        ("textMessages", DevScenario(seed: 42, powerUps: [(.phone, 1)], godMode: true)),
        ("trafficZone",  DevScenario(seed: 42, obstacles: [(.conePattern, 1)], godMode: true)),
    ]

    static func preset(named name: String) -> DevScenario? {
        presets.first { $0.name == name }?.scenario
    }
}

// MARK: - Launch arguments

extension DevScenario {
    enum LaunchError: Error, CustomStringConvertible {
        case missingValue(String)
        case unknownPreset(String)

        var description: String {
            switch self {
            case .missingValue(let flag):
                return "\(flag) needs a value"
            case .unknownPreset(let name):
                return "Unknown preset '\(name)'. Presets: \(DevScenario.presets.map(\.name).joined(separator: ", "))"
            }
        }
    }

    /// The scenario named by `-devScenario <preset>` or given inline by
    /// `-devScenarioJSON '<json>'`, or `nil` when neither is present.
    /// `-devAutopilot` turns the autopilot on for either.
    static func fromLaunchArguments(_ arguments: [String]) throws -> DevScenario? {
        var scenario = try scenario(fromArguments: arguments)
        if arguments.contains("-devAutopilot") { scenario?.autopilot = true }
        return scenario
    }

    private static func scenario(fromArguments arguments: [String]) throws -> DevScenario? {
        func value(after flag: String) throws -> String? {
            guard let index = arguments.firstIndex(of: flag) else { return nil }
            guard arguments.indices.contains(index + 1) else { throw LaunchError.missingValue(flag) }
            return arguments[index + 1]
        }
        if let json = try value(after: "-devScenarioJSON") {
            return try JSONDecoder().decode(DevScenario.self, from: Data(json.utf8))
        }
        if let name = try value(after: "-devScenario") {
            guard let scenario = preset(named: name) else { throw LaunchError.unknownPreset(name) }
            return scenario
        }
        return nil
    }
}

// MARK: - JSON

/// Same field names as the properties; spawn pools use `tuning.json`'s row format, and
/// power-ups are named `wrap`, `monsterTruck`, `booze`, `oneUp`, `x2` or `x3`.
extension DevScenario: Decodable {
    private enum CodingKeys: String, CodingKey {
        case seed, obstacles, environment, powerUps, startElapsed, startPowerUps
        case lives, godMode, timeScale, autopilot, hitboxes, bank, unlockAll, useRealProfile
    }

    struct UnknownPowerUp: Error {
        let name: String
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func pool<T>(_ key: CodingKeys, _ parse: (String) -> T?) throws -> [(T, Int)]? {
            try c.decodeIfPresent([SpawnTables.Row].self, forKey: key).map { try SpawnTables.pool($0, parse) }
        }
        self.init(
            seed: try c.decodeIfPresent(UInt64.self, forKey: .seed),
            obstacles: try pool(.obstacles, ObstacleSpawn.init(name:)),
            environment: try pool(.environment, EnvSpawnType.init(name:)),
            powerUps: try pool(.powerUps, PowerUpSpawn.init(name:)),
            startElapsed: try c.decodeIfPresent(Double.self, forKey: .startElapsed),
            startPowerUps: try (c.decodeIfPresent([String].self, forKey: .startPowerUps) ?? []).map { name in
                guard let type = PowerUpType(devName: name) else { throw UnknownPowerUp(name: name) }
                return type
            },
            lives: try c.decodeIfPresent(Int.self, forKey: .lives),
            godMode: try c.decodeIfPresent(Bool.self, forKey: .godMode) ?? false,
            timeScale: try c.decodeIfPresent(Double.self, forKey: .timeScale) ?? 1,
            autopilot: try c.decodeIfPresent(Bool.self, forKey: .autopilot) ?? false,
            hitboxes: try c.decodeIfPresent(Bool.self, forKey: .hitboxes) ?? false,
            bank: try c.decodeIfPresent(Int.self, forKey: .bank),
            unlockAll: try c.decodeIfPresent(Bool.self, forKey: .unlockAll) ?? false,
            useRealProfile: try c.decodeIfPresent(Bool.self, forKey: .useRealProfile) ?? false
        )
    }
}

extension PowerUpType {
    /// `wrap`, `monsterTruck`, `booze`, `oneUp`, `x2` or `x3`.
    init?(devName: String) {
        switch devName {
        case "wrap":         self = .wrap
        case "monsterTruck": self = .monsterTruck
        case "booze":        self = .booze
        case "oneUp":        self = .oneUp
        case "x2":           self = .multiplier(2)
        case "x3":           self = .multiplier(3)
        default:             return nil
        }
    }
}

// MARK: - Dev names

extension ObstacleSpawn {
    /// Everything the obstacle spawner can roll (cones and barricades only come in patterns).
    static var devChoices: [ObstacleSpawn] {
        ObstacleType.allCases.filter { $0 != .cone && $0 != .barricade }.map(ObstacleSpawn.single) + [.conePattern]
    }

    var devName: String {
        switch self {
        case .single(let type): return type.rawValue
        case .conePattern:      return "conePattern"
        }
    }
}

extension EnvSpawnType {
    static let devChoices: [EnvSpawnType] = [.plant, .coinPattern]

    var devName: String {
        switch self {
        case .plant:       return "plant"
        case .coinPattern: return "coinPattern"
        }
    }
}

extension PowerUpSpawn {
    static let devChoices: [PowerUpSpawn] = [
        .powerUp(.oneUp), .powerUp(.monsterTruck), .powerUp(.wrap), .multiplier, .phone, .powerUp(.booze), .nothing,
    ]

    var devName: String {
        switch self {
        case .powerUp(let type): return type.devName
        case .multiplier:        return "multiplier"
        case .phone:             return "phone"
        case .nothing:           return "nothing"
        }
    }
}

extension PowerUpType {
    /// The power-ups a run can start with.
    static let devChoices: [PowerUpType] = [.wrap, .monsterTruck, .booze, .oneUp, .multiplier(2), .multiplier(3)]

    /// Inverse of `init(devName:)`.
    var devName: String {
        switch self {
        case .wrap:              return "wrap"
        case .monsterTruck:      return "monsterTruck"
        case .booze:             return "booze"
        case .oneUp:             return "oneUp"
        case .multiplier(let n): return "x\(n)"
        }
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// The scenario from the launch arguments; `MainMenuView` starts it on launch.
    @Entry var devLaunchScenario: DevScenario? = nil
}
#endif
