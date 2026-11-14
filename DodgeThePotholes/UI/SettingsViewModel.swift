import Foundation
import Observation

/// `@Observable` state for the Settings, Audio and Car Select screens.
///
/// Reads and writes the player's preferences through `PersistenceServiceProtocol`,
/// so changes are saved immediately and picked up by the next run.
@Observable
@MainActor
final class SettingsViewModel {

    private let persistence: any PersistenceServiceProtocol
    private let catalog: GameCatalog

    /// - Parameters:
    ///   - persistence: Saved preferences and owned items.
    ///   - catalog: The cars and songs to choose from.
    init(persistence: any PersistenceServiceProtocol, catalog: GameCatalog = .bundled) {
        self.persistence = persistence
        self.catalog = catalog
    }

    // MARK: - Sound

    var isMusicEnabled: Bool {
        get { persistence.isMusicEnabled }
        set { persistence.isMusicEnabled = newValue }
    }

    var isSFXEnabled: Bool {
        get { persistence.isSFXEnabled }
        set { persistence.isSFXEnabled = newValue }
    }

    // MARK: - Car

    /// Every car, in display order.
    var cars: [CarSkin] { catalog.cars }

    var selectedCar: CarSkin { persistence.selectedCar }

    /// Whether the player owns `car`. A car with no unlock key is free.
    func isOwned(_ car: CarSkin) -> Bool { persistence.isUnlocked(car) }

    /// Selects `car` for the next run if the player owns it.
    func select(_ car: CarSkin) {
        guard isOwned(car) else { return }
        persistence.selectedCar = car
    }

    // MARK: - Song

    var selectedSong: GameSound { persistence.selectedSong }

    /// Songs the player owns, in shop order.
    var ownedSongs: [GameSound] {
        catalog.shopItems
            .filter { $0.category == .song && persistence.isUnlocked($0) }
            .compactMap { GameSound(rawValue: $0.id) }
    }

    /// Shop display name for a song, e.g. "Hot Pursuit".
    func displayName(of song: GameSound) -> String {
        catalog.shopItem(id: song.rawValue)?.displayName ?? song.rawValue
    }

    /// Selects the next owned song, wrapping around. Legacy cycled songs the same way.
    func nextSong() { cycleSong(by: 1) }

    /// Selects the previous owned song, wrapping around.
    func previousSong() { cycleSong(by: -1) }

    private func cycleSong(by step: Int) {
        let songs = ownedSongs
        guard let first = songs.first else { return }
        guard let index = songs.firstIndex(of: selectedSong) else {
            persistence.selectedSong = first
            return
        }
        persistence.selectedSong = songs[(index + step + songs.count) % songs.count]
    }
}
