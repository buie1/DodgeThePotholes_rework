#if DEBUG
import Foundation

/// Writes dev runs to `Documents/devlog.jsonl` as JSON Lines. Debug builds only.
///
/// It sits between the engine and the view model: each delegate callback is logged,
/// then forwarded unchanged. About once a second of play it also logs a snapshot of
/// the run. The file starts fresh each app launch; `scripts/dev-run.sh` copies it out
/// of the simulator. Every line has `t` (seconds of play) and `event`.
@MainActor
final class DevEventLog: GameEngineDelegate {

    static let shared = DevEventLog()

    static let fileName = "devlog.jsonl"

    /// Where the log is written.
    let url: URL
    private let handle: FileHandle?
    private weak var forward: (any GameEngineDelegate)?
    private var nextSnapshot: Double = 0

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = documents.appendingPathComponent(Self.fileName)
        FileManager.default.createFile(atPath: url.path, contents: nil)   // truncates
        handle = try? FileHandle(forWritingTo: url)
    }

    /// Starts logging a new run and forwards its callbacks to `delegate`.
    func beginRun(_ scenario: DevScenario, seed: UInt64, forwardingTo delegate: any GameEngineDelegate) {
        forward = delegate
        nextSnapshot = 0
        write(t: 0, "runStart", ["seed": String(seed), "godMode": scenario.godMode,
                                 "timeScale": scenario.timeScale, "autopilot": scenario.autopilot,
                                 "startElapsed": scenario.startElapsed ?? 0])
    }

    // MARK: - GameEngineDelegate

    func engine(_ engine: GameEngine, didUpdateScore score: Int) {
        if engine.elapsed >= nextSnapshot {
            nextSnapshot = engine.elapsed.rounded(.down) + 1
            snapshot(engine)
        }
        forward?.engine(engine, didUpdateScore: score)
    }

    func engine(_ engine: GameEngine, didUpdateMoney money: Int) {
        forward?.engine(engine, didUpdateMoney: money)
    }

    func engine(_ engine: GameEngine, didUpdateLives lives: Int) {
        write(engine, "lives", ["lives": lives])
        forward?.engine(engine, didUpdateLives: lives)
    }

    func engine(_ engine: GameEngine, didChangePlayerState state: PlayerState) {
        write(engine, "playerState", ["state": "\(state)"])
        forward?.engine(engine, didChangePlayerState: state)
    }

    func engine(_ engine: GameEngine, didActivatePowerUp powerUp: PowerUpState) {
        write(engine, "powerUpOn", ["type": "\(powerUp.type)", "seconds": powerUp.totalSeconds])
        forward?.engine(engine, didActivatePowerUp: powerUp)
    }

    func engine(_ engine: GameEngine, didDeactivatePowerUp type: PowerUpType) {
        write(engine, "powerUpOff", ["type": "\(type)"])
        forward?.engine(engine, didDeactivatePowerUp: type)
    }

    func engine(_ engine: GameEngine, didTriggerTextMessageAt index: Int) {
        write(engine, "textMessage", ["index": index])
        forward?.engine(engine, didTriggerTextMessageAt: index)
    }

    func engine(_ engine: GameEngine, didRaiseAlert alert: GameAlert) {
        write(engine, "alert", ["message": alert.message])
        forward?.engine(engine, didRaiseAlert: alert)
    }

    func engineDidEnd(_ engine: GameEngine, finalScore: Int, moneyEarned: Int) {
        write(engine, "gameOver", ["score": finalScore, "money": moneyEarned])
        forward?.engineDidEnd(engine, finalScore: finalScore, moneyEarned: moneyEarned)
    }

    func engine(_ engine: GameEngine, requestsSound sound: GameSound) {
        if sound != .money { write(engine, "sound", ["name": sound.rawValue]) }
        forward?.engine(engine, requestsSound: sound)
    }

    func engine(_ engine: GameEngine, requestsHaptic pattern: HapticPattern) {
        forward?.engine(engine, requestsHaptic: pattern)
    }

    // MARK: - Writing

    private func snapshot(_ engine: GameEngine) {
        write(engine, "snapshot", [
            "score": engine.score,
            "money": engine.money,
            "lives": engine.player.lives,
            "state": "\(engine.player.state)",
            "x": Self.decimal(engine.player.position.x, places: 1),
            "travelDuration": Self.decimal(engine.travelDuration),
            "obstacles": engine.obstacles.count,
            "powerUps": engine.powerUpEntities.count,
            "coins": engine.coins.count,
        ])
    }

    private func write(_ engine: GameEngine, _ event: String, _ fields: [String: Any]) {
        write(t: engine.elapsed, event, fields)
    }

    private func write(t: Double, _ event: String, _ fields: [String: Any]) {
        var line = fields
        line["t"] = Self.decimal(t)
        line["event"] = event
        guard let handle,
              let data = try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys]) else { return }
        handle.write(data + Data("\n".utf8))
    }

    /// `value` rounded for the log. A `Decimal`, because JSON-encoding a `Double`
    /// can print 1.9 as 1.8999999999999999.
    private static func decimal(_ value: Double, places: Int = 2) -> Decimal {
        Decimal(string: String(format: "%.\(places)f", value)) ?? Decimal(value)
    }
}
#endif
