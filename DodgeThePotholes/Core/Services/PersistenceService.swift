import Foundation
import Observation
import SwiftData

// MARK: - Protocol

/// Outcome of a shop purchase attempt.
enum PurchaseResult: Equatable {
    case purchased
    case insufficientFunds
    case alreadyOwned
}

/// One finished run from the local score history.
struct RunRecord: Equatable {
    let score: Int
    let moneyEarned: Int
    let date: Date
}

/// Saved player progress: bank balance, high score, shop unlocks and preferences.
///
/// The protocol boundary lets tests and Previews swap in an in-memory or mock store.
@MainActor
protocol PersistenceServiceProtocol: AnyObject {
    /// Banked money available to spend in the shop.
    var money: Int { get }
    var highScore: Int { get }

    var selectedCar: CarSkin { get set }
    var selectedSong: GameSound { get set }
    var isSFXEnabled: Bool { get set }
    var isMusicEnabled: Bool { get set }

    /// `true` once the tank is bought. It replaces the monster-truck sprite.
    var hasTank: Bool { get }
    /// `true` while a bought extra life is waiting for the next run.
    var extraLifePending: Bool { get }

    /// Whether the item with this `ShopItem.id` is owned (or, for the extra life, pending).
    func isUnlocked(_ itemKey: String) -> Bool

    /// Spends money on `item` when it isn't owned and the player can afford it.
    func purchase(_ item: ShopItem) -> PurchaseResult

    /// Spends the pending extra life, if any.
    /// - Returns: `true` when the run should start with one more life.
    func consumeExtraLife() -> Bool

    /// Banks a finished run's earnings and records it in the score history.
    /// - Returns: `true` when `score` is a new high score.
    @discardableResult
    func recordRun(score: Int, moneyEarned: Int) -> Bool

    /// The highest-scoring runs, best first (ties: earliest first).
    func bestRuns(limit: Int) -> [RunRecord]
}

extension PersistenceServiceProtocol {
    func isUnlocked(_ item: ShopItem) -> Bool { isUnlocked(item.id) }

    /// A car with no unlock key is free; the others need their unlock.
    func isUnlocked(_ car: CarSkin) -> Bool {
        car.unlockKey.map { isUnlocked($0) } ?? true
    }
}

// MARK: - SwiftData implementation

/// SwiftData-backed persistence around a single `PlayerProfile` record.
///
/// On first launch it copies the legacy `UserDefaults` progress into the profile,
/// guarded by the `"v2_migrated"` flag.
@Observable
@MainActor
final class SwiftDataPersistenceService: PersistenceServiceProtocol {

    /// Songs every player owns from the start (legacy: only "hot-pursuit.wav").
    static let freeSongs: [GameSound] = [.hotPursuit]

    /// Retained so the context isn't reset when the caller drops its container.
    private let container: ModelContainer
    private let context: ModelContext
    private let profile: PlayerProfile

    /// - Parameters:
    ///   - container: The app's model container. Its main context is used.
    ///   - defaults: Where legacy progress is migrated from.
    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        context = container.mainContext
        if let existing = try? context.fetch(FetchDescriptor<PlayerProfile>()).first {
            profile = existing
        } else {
            profile = PlayerProfile()
            context.insert(profile)
            for song in Self.freeSongs {
                profile.unlocks.append(UnlockRecord(itemKey: song.rawValue))
            }
            Self.migrateLegacyDefaults(defaults, into: profile)
            save()
        }
    }

    /// Creates the model container for the player's saved data.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: PlayerProfile.self, UnlockRecord.self, ScoreEntry.self,
                                  configurations: config)
    }

    /// A fresh store that lives only in memory, for tests and Previews.
    static func inMemory(defaults: UserDefaults = UserDefaults(suiteName: "preview")!) -> SwiftDataPersistenceService {
        SwiftDataPersistenceService(container: try! makeContainer(inMemory: true), defaults: defaults)
    }

    // MARK: - Progress

    var money: Int { profile.money }
    var highScore: Int { profile.highScore }
    var extraLifePending: Bool { profile.extraLifePending }
    var hasTank: Bool { isUnlocked("tank") }

    // MARK: - Preferences

    var selectedCar: CarSkin {
        get { GameCatalog.bundled.car(id: profile.selectedCarKey) ?? GameCatalog.bundled.defaultCar }
        set { profile.selectedCarKey = newValue.id; save() }
    }

    var selectedSong: GameSound {
        get { GameSound(rawValue: profile.selectedSongFilename) ?? .hotPursuit }
        set { profile.selectedSongFilename = newValue.rawValue; save() }
    }

    var isSFXEnabled: Bool {
        get { profile.isSFXEnabled }
        set { profile.isSFXEnabled = newValue; save() }
    }

    var isMusicEnabled: Bool {
        get { profile.isMusicEnabled }
        set { profile.isMusicEnabled = newValue; save() }
    }

    // MARK: - Shop

    func isUnlocked(_ itemKey: String) -> Bool {
        if itemKey == "life" { return profile.extraLifePending }
        return profile.unlocks.contains { $0.itemKey == itemKey && $0.isPurchased }
    }

    func purchase(_ item: ShopItem) -> PurchaseResult {
        guard !isUnlocked(item) else { return .alreadyOwned }
        guard profile.money >= item.cost else { return .insufficientFunds }

        profile.money -= item.cost
        if item.category == .extraLife {
            profile.extraLifePending = true
        } else {
            profile.unlocks.append(UnlockRecord(itemKey: item.id))
        }
        save()
        return .purchased
    }

    func consumeExtraLife() -> Bool {
        guard profile.extraLifePending else { return false }
        profile.extraLifePending = false
        save()
        return true
    }

    // MARK: - Runs

    @discardableResult
    func recordRun(score: Int, moneyEarned: Int) -> Bool {
        profile.money += moneyEarned
        profile.scoreHistory.append(ScoreEntry(score: score, moneyEarned: moneyEarned))
        let isNewHighScore = score > profile.highScore
        if isNewHighScore { profile.highScore = score }
        save()
        return isNewHighScore
    }

    func bestRuns(limit: Int) -> [RunRecord] {
        var descriptor = FetchDescriptor<ScoreEntry>(
            sortBy: [SortDescriptor(\.score, order: .reverse), SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = limit
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.map { RunRecord(score: $0.score, moneyEarned: $0.moneyEarned, date: $0.date) }
    }

    // MARK: - Private

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save player profile: \(error)")
        }
    }

    // MARK: - Legacy migration

    static let migrationFlagKey = "v2_migrated"

    /// Copies legacy `UserDefaults` progress into `profile`, once per install.
    /// Legacy keys are left in place.
    static func migrateLegacyDefaults(_ defaults: UserDefaults, into profile: PlayerProfile) {
        guard !defaults.bool(forKey: migrationFlagKey) else { return }
        defer { defaults.set(true, forKey: migrationFlagKey) }

        profile.money     = defaults.integer(forKey: "money")
        profile.highScore = defaults.integer(forKey: "highscore")
        if let car = defaults.string(forKey: "car"), GameCatalog.bundled.car(id: car) != nil {
            profile.selectedCarKey = car
        }
        if let song = defaults.string(forKey: "song_selected"), GameSound(rawValue: song) != nil {
            profile.selectedSongFilename = song
        }
        profile.isSFXEnabled     = defaults.object(forKey: "sfx") as? Bool ?? true
        profile.isMusicEnabled   = defaults.object(forKey: "music") as? Bool ?? true
        profile.extraLifePending = defaults.bool(forKey: "life")

        var owned = ["redcar", "greencar", "tank"].filter { defaults.bool(forKey: $0) }
        let songs = defaults.dictionary(forKey: "songs") as? [String: Bool] ?? [:]
        owned += songs.filter(\.value).map(\.key).sorted()

        let existing = Set(profile.unlocks.map(\.itemKey))
        for key in owned where !existing.contains(key) {
            profile.unlocks.append(UnlockRecord(itemKey: key, purchasedDate: nil))
        }
    }
}
