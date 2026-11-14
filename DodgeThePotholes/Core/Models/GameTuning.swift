import Foundation

/// Gameplay balance values, loaded from `Resources/Config/tuning.json`.
///
/// Holds the numbers worth tuning without a code change (lives, speed ramp, spawn
/// rates and weights, power-up durations). Geometry tied to the art stays in
/// `GameConfig`. The engine takes a `GameTuning` value, so a remotely fetched copy
/// can replace `bundled` later.
struct GameTuning: Decodable, Equatable {

    struct Lives: Decodable, Equatable {
        let start: Int
        let max: Int
    }

    /// Legacy `gameSpeed`: the seconds an obstacle takes to cross the screen.
    struct Speed: Decodable, Equatable {
        /// Starting travel duration (seconds to cross the full world height).
        let startTravelDuration: Double
        /// Fastest the game ever gets.
        let minTravelDuration: Double
        /// How often (seconds) the travel duration steps down.
        let rampInterval: Double
        /// How much the travel duration decreases each ramp step.
        let rampStep: Double
    }

    /// Seconds between spawns.
    struct SpawnIntervals: Decodable, Equatable {
        let obstacle: Double
        let environment: Double
        let powerUp: Double
        /// Seconds (at start speed) the obstacle spawner pauses for a cone pattern.
        let conePatternPause: Double
    }

    /// Seconds each timed effect lasts.
    struct Durations: Decodable, Equatable {
        let wrap: Double
        let multiplier: Double
        let monsterTruck: Double
        let booze: Double
        /// Post-collision invincibility (legacy flash: 8 × 0.6 s).
        let recovery: Double
    }

    let lives: Lives
    /// Score points awarded per second of survival (legacy: +1 per frame at 60 fps).
    let pointsPerSecond: Double
    let speed: Speed
    let spawnIntervals: SpawnIntervals
    let durations: Durations
    /// Spawn pools. The power-up pool reproduces the odds the legacy `addPowerUp()`
    /// actually produced (it re-rolled the die in every `else if`).
    let weights: SpawnTables

    // MARK: - Loading

    enum LoadError: Error {
        case missingResource(String)
    }

    /// The tuning shipped in the app bundle.
    static let bundled: GameTuning = {
        do {
            return try load()
        } catch {
            preconditionFailure("Bundled tuning.json failed to load: \(error)")
        }
    }()

    /// Loads and decodes `tuning.json`.
    /// - Parameter bundle: The bundle containing the JSON; defaults to the app bundle.
    static func load(in bundle: Bundle = .main) throws -> GameTuning {
        guard let url = bundle.url(forResource: "tuning", withExtension: "json") else {
            throw LoadError.missingResource("tuning.json")
        }
        return try JSONDecoder().decode(GameTuning.self, from: Data(contentsOf: url))
    }
}

// MARK: - Spawn table decoding

extension SpawnTables: Decodable {
    private enum CodingKeys: String, CodingKey { case obstacles, environment, powerUps }

    /// One `{ "spawn": name, "weight": n }` row. Rows keep their JSON order, so a
    /// seeded run rolls the same pool the same way.
    private struct Row: Decodable {
        let spawn: String
        let weight: Int
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func pool<T>(_ key: CodingKeys, _ parse: (String) -> T?) throws -> [(T, Int)] {
            try container.decode([Row].self, forKey: key).map { row in
                guard let spawn = parse(row.spawn) else {
                    throw DecodingError.dataCorruptedError(forKey: key, in: container,
                                                           debugDescription: "Unknown spawn '\(row.spawn)'")
                }
                return (spawn, row.weight)
            }
        }
        self.init(obstacles: try pool(.obstacles, ObstacleSpawn.init(name:)),
                  environment: try pool(.environment, EnvSpawnType.init(name:)),
                  powerUps: try pool(.powerUps, PowerUpSpawn.init(name:)))
    }
}

extension SpawnTables: Equatable {
    static func == (lhs: SpawnTables, rhs: SpawnTables) -> Bool {
        lhs.obstacles.elementsEqual(rhs.obstacles, by: ==)
            && lhs.environment.elementsEqual(rhs.environment, by: ==)
            && lhs.powerUps.elementsEqual(rhs.powerUps, by: ==)
    }
}

extension ObstacleSpawn {
    /// `"conePattern"`, or an `ObstacleType` raw value.
    init?(name: String) {
        if name == "conePattern" { self = .conePattern; return }
        guard let type = ObstacleType(rawValue: name) else { return nil }
        self = .single(type)
    }
}

extension EnvSpawnType {
    init?(name: String) {
        switch name {
        case "plant":       self = .plant
        case "coinPattern": self = .coinPattern
        default:            return nil
        }
    }
}

extension PowerUpSpawn {
    init?(name: String) {
        switch name {
        case "oneUp":        self = .powerUp(.oneUp)
        case "monsterTruck": self = .powerUp(.monsterTruck)
        case "wrap":         self = .powerUp(.wrap)
        case "booze":        self = .powerUp(.booze)
        case "multiplier":   self = .multiplier
        case "phone":        self = .phone
        case "nothing":      self = .nothing
        default:             return nil
        }
    }
}
