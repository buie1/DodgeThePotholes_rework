import AVFoundation

// MARK: - Protocol

/// Plays background music (looping) and one-shot SFX.
/// Conforming types must be class-bound so `GameViewModel` can hold them by reference.
protocol AudioServiceProtocol: AnyObject {
    /// Master switch for background music. Changing silences / restores the current track.
    var isMusicEnabled: Bool { get set }
    /// Master switch for sound effects.
    var isSFXEnabled: Bool { get set }

    /// Routes a `GameSound` to either `startMusic(_:)` or the SFX pool.
    func play(_ sound: GameSound)

    /// Begins looping a background music track, replacing any currently playing track.
    func startMusic(_ track: GameSound)

    /// Fades out and stops the current music track.
    func stopMusic()

    /// Applies a slow-down effect to the current music track (drunk power-up).
    func setDrunkMode(_ enabled: Bool)
}

// MARK: - Concrete implementation

/// `AVAudioPlayer`-backed audio service.
///
/// **Music**: single looping `AVAudioPlayer` with rate control (`enableRate = true`).
/// **SFX**: a small pool of preloaded players per sound to allow same-sound overlap.
final class AudioService: AudioServiceProtocol {

    // MARK: - State

    var isMusicEnabled: Bool = true {
        didSet { musicPlayer?.volume = isMusicEnabled ? musicVolume : 0 }
    }
    var isSFXEnabled: Bool = true

    // MARK: - Constants

    private let musicVolume: Float     = 0.65
    private let sfxVolume:   Float     = 1.0
    /// Rate applied to music while drunk mode is active (0.5 = half speed / pitch).
    private let drunkRate:   Float     = 0.6
    private let normalRate:  Float     = 1.0
    /// Max additional player copies created per SFX when all pool slots are busy.
    private let maxPoolSize: Int       = 3

    // MARK: - Players

    private var musicPlayer: AVAudioPlayer?
    /// Keyed pools of preloaded players. Multiple players per sound allow overlap.
    private var sfxPool: [GameSound: [AVAudioPlayer]] = [:]

    // MARK: - Init

    init() {
        configureSession()
        preloadSFX()
    }

    // MARK: - AudioServiceProtocol

    func play(_ sound: GameSound) {
        if sound.isBackgroundMusic {
            startMusic(sound)
        } else {
            playSFX(sound)
        }
    }

    func startMusic(_ track: GameSound) {
        guard track.isBackgroundMusic else { return }
        musicPlayer?.stop()
        musicPlayer = nil
        guard isMusicEnabled, let player = makePlayer(for: track) else { return }
        player.enableRate        = true
        player.numberOfLoops     = -1   // loop forever
        player.volume            = musicVolume
        player.prepareToPlay()
        player.play()
        musicPlayer = player
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    func setDrunkMode(_ enabled: Bool) {
        musicPlayer?.rate = enabled ? drunkRate : normalRate
    }

    // MARK: - Private helpers

    private func configureSession() {
        do {
            // .playback: audio continues with silent switch; ducks other apps.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                             options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal — game will still function without audio session.
        }
    }

    private func preloadSFX() {
        for sound in GameSound.sfxCases {
            guard let player = makePlayer(for: sound) else { continue }
            player.enableRate = true
            player.volume     = sfxVolume
            player.prepareToPlay()
            sfxPool[sound] = [player]
        }
    }

    private func playSFX(_ sound: GameSound) {
        guard isSFXEnabled else { return }
        guard let pool = sfxPool[sound] else { return }

        // Prefer an idle slot.
        if let idle = pool.first(where: { !$0.isPlaying }) {
            idle.currentTime = 0
            idle.play()
            return
        }

        // All slots busy and pool not yet at max — create an extra copy.
        guard pool.count < maxPoolSize, let extra = makePlayer(for: sound) else { return }
        extra.enableRate = true
        extra.volume     = sfxVolume
        extra.prepareToPlay()
        extra.play()
        sfxPool[sound]?.append(extra)
    }

    /// Builds an `AVAudioPlayer` from a `GameSound`'s raw file name, or `nil` if not found.
    private func makePlayer(for sound: GameSound) -> AVAudioPlayer? {
        guard let (name, ext) = sound.resourceComponents,
              let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }
}

// MARK: - GameSound helpers (AudioService-internal)

private extension GameSound {

    /// Returns `true` for looping background music tracks (the five purchasable songs).
    var isBackgroundMusic: Bool {
        switch self {
        case .hotPursuit, .bornLucky, .raceDuel, .catchMe, .urbanChase: return true
        default: return false
        }
    }

    /// All cases that are one-shot SFX (not background music).
    static let sfxCases: [GameSound] = [
        .carSkid, .carHonk, .crash, .dogWhimper, .explosion,
        .scream, .textTone, .ambulance, .police, .gameStart,
        .money, .ohMyGod, .pewPew, .rampage, .monsterTruck,
    ]

    /// Splits `"filename.ext"` into `("filename", "ext")`.
    var resourceComponents: (name: String, ext: String)? {
        let parts = rawValue.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
}
