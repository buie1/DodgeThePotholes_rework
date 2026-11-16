import Foundation
import Observation

/// `@Observable` state for the Settings, Audio, Controls and Car Select screens.
///
/// Reads and writes the player's preferences through `PersistenceServiceProtocol`,
/// so changes are saved immediately and picked up by the next run.
@Observable
@MainActor
final class SettingsViewModel {

    private let persistence: any PersistenceServiceProtocol
    private let catalog: GameCatalog
    private let motion: any MotionServiceProtocol

    /// - Parameters:
    ///   - persistence: Saved preferences and owned items.
    ///   - catalog: The cars and songs to choose from.
    ///   - motion: The accelerometer, for the Controls screen's tilt preview and calibration.
    init(persistence: any PersistenceServiceProtocol, catalog: GameCatalog = .bundled,
         motion: any MotionServiceProtocol = MotionService()) {
        self.persistence = persistence
        self.catalog = catalog
        self.motion = motion
    }

    // MARK: - Controls

    var controlScheme: ControlScheme {
        get { persistence.controlScheme }
        set { persistence.controlScheme = newValue }
    }

    /// `false` without an accelerometer (e.g. the Simulator), where only drag works.
    var isTiltAvailable: Bool { motion.isAvailable }

    /// Live steering from the current tilt in [-1, 1], while the preview runs.
    private(set) var tiltPreview: Double = 0

    /// Starts showing live tilt, relative to the saved neutral angle.
    func startTiltPreview() {
        motion.neutralTilt = persistence.tiltNeutral
        motion.start { [weak self] steering in self?.tiltPreview = steering }
    }

    func stopTiltPreview() {
        motion.stop()
        tiltPreview = 0
    }

    /// Makes the phone's current angle count as straight ahead.
    func calibrateTilt() {
        guard let raw = motion.rawTilt else { return }
        persistence.tiltNeutral = raw
        motion.neutralTilt = raw
        tiltPreview = 0
    }

    /// Forgets calibration: holding the phone level is straight ahead again.
    func resetTiltCalibration() {
        persistence.tiltNeutral = 0
        motion.neutralTilt = 0
    }

    var isTiltCalibrated: Bool { persistence.tiltNeutral != 0 }

    // MARK: - First launch

    /// `true` until a new player picks Tilt or Drag.
    var needsControlChoice: Bool { persistence.needsControlChoice }

    /// The first-launch choice: saves the scheme and doesn't ask again.
    func chooseControls(_ scheme: ControlScheme) {
        persistence.controlScheme = scheme
        persistence.hasChosenControls = true
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
