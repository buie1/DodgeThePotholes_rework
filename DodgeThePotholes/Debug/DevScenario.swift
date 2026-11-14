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
    static func fromLaunchArguments(_ arguments: [String]) throws -> DevScenario? {
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
        case lives, godMode, timeScale, bank, unlockAll, useRealProfile
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

// MARK: - Environment

extension EnvironmentValues {
    /// The scenario from the launch arguments; `MainMenuView` starts it on launch.
    @Entry var devLaunchScenario: DevScenario? = nil
}
#endif
