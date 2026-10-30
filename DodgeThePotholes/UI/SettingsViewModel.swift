import Foundation
import Observation

/// `@Observable` state for the Settings and Audio screens.
///
/// Reads and writes the player's preferences through `PersistenceServiceProtocol`,
/// so changes are saved immediately and picked up by the next run.
@Observable
@MainActor
final class SettingsViewModel {

    private let persistence: any PersistenceServiceProtocol

    init(persistence: any PersistenceServiceProtocol) {
        self.persistence = persistence
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

    // MARK: - Song

    var selectedSong: GameSound { persistence.selectedSong }

    /// Songs the player owns, in shop order.
    var ownedSongs: [GameSound] {
        ShopItem.allItems
            .filter { $0.category == .song && persistence.isUnlocked($0) }
            .compactMap { GameSound(rawValue: $0.id) }
    }

    /// Shop display name for a song, e.g. "Hot Pursuit".
    func displayName(of song: GameSound) -> String {
        ShopItem.allItems.first { $0.id == song.rawValue }?.displayName ?? song.rawValue
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
