import Foundation

/// All audio cues the engine can request, keyed to bundled file names.
enum GameSound: String, CaseIterable {
    // MARK: SFX
    case carSkid      = "carskid.wav"
    case carHonk      = "car_honk.mp3"
    case crash        = "crash1.mp3"
    case dogWhimper   = "dog_wimper.mp3"
    case explosion    = "explosion.mp3"
    case scream       = "scream_in_pain.mp3"
    case textTone     = "text_tone.mp3"
    case ambulance    = "ambulance_s.mp3"
    case police       = "police_s.wav"
    case gameStart    = "start.wav"
    case money        = "money.aiff"
    case ohMyGod      = "oh_my_god.mp3"
    case pewPew       = "pew-pew-lei.caf"
    case rampage      = "RAMPAGE.mp3"
    case monsterTruck = "monster_truck_jam.mp3"

    // MARK: Background music tracks
    case hotPursuit  = "hot-pursuit.wav"
    case bornLucky   = "born-lucky.wav"
    case raceDuel    = "race_duel.wav"
    case catchMe     = "catch_me.wav"
    case urbanChase  = "urban_chase.wav"
}

/// Semantic haptic patterns the engine can request.
/// The HapticsManager maps these to CoreHaptics events.
enum HapticPattern {
    case collision
    case coinPickup
    case powerUpActivated
    case lifeGained
}
