# DodgeThePotholes — Legacy-to-Modern Migration Plan

> **Source**: `legacy_source/` — SpriteKit/UIKit, CocoaPods, Firebase, iOS 10 target
> **Target**: `DodgeThePotholes/` — SwiftUI + `@Observable`, pure-Swift engine rendered with SpriteKit, GameKit, SwiftData, iOS 17+, Swift 6

> **Architecture update (Oct 2026).** The game was built as a **pure-Swift `GameEngine`**
> (logic, AABB collisions, spawning, power-ups, horn) **rendered by a SpriteKit
> `GameRenderScene`**, not as an SKPhysics `GameScene`. Where this document mentions
> `GameScene`, `GameSceneDelegate`, `PhysicsCategory`, `ContactHandler`, `SpawnManager`,
> `SpeedController`, or the per-node classes in `Obstacles/` and `PowerUps/`, read it as
> superseded by:
>
> | Planned | Built |
> |---|---|
> | `GameScene` + SKPhysics contacts | `Core/GameEngine/GameEngine.swift` (AABB) |
> | `GameSceneDelegate` | `Core/GameEngine/GameEngineDelegate.swift` + `GameEngine.frameEvents` |
> | `SpawnManager`, `SpeedController`, node `generatePosition` | `Core/GameEngine/EntitySpawner.swift` + `SpawnTables` |
> | `*ObstacleNode`, `*PowerUpNode`, `PlayerNode` | `Core/Rendering/EntityNodeFactory.swift`, `PlayerNode.swift` |
> | `AccelerometerManager` | `Core/Services/MotionService.swift` |
>
> The engine runs in a **750-unit-wide world** (the legacy scene was 750 × 1334) with the
> screen's aspect ratio, so every legacy size and position ports unchanged. Assets live in
> `DodgeThePotholes/Resources/`. Gameplay rules are covered by `DodgeThePotholesTests`.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Target File Structure](#2-target-file-structure)
3. [Component Mapping Table](#3-component-mapping-table)
4. [ViewModel Layer Design](#4-viewmodel-layer-design)
5. [GameSceneDelegate Protocol](#5-gamescenedelegate-protocol)
6. [Physics System](#6-physics-system)
7. [Audio Service](#7-audio-service)
8. [Persistence (SwiftData + Migration)](#8-persistence-swiftdata--migration)
9. [Spawn System](#9-spawn-system)
10. [Asset Migration](#10-asset-migration)
11. [Implementation Phases](#11-implementation-phases)
12. [Key Risks & Decisions](#12-key-risks--decisions)

---

## 1. Architecture Overview

The legacy app uses **SpriteKit scenes as both game engine and UI**. Every `SKScene` subclass handles touch input, navigation (`self.view?.presentScene(...)`), `UserDefaults`, and `UIAlertController` in one monolith.

The modern architecture separates these concerns into strict layers:

```
┌─────────────────────────────────────────────────┐
│            SwiftUI Layer (Views)                │
│  MainMenuView, GameView, ShopView, …            │
└────────────────────┬────────────────────────────┘
                     │ observes @Observable
┌────────────────────▼────────────────────────────┐
│          ViewModel Layer (@Observable)          │
│  GameViewModel, ShopViewModel, SettingsViewModel│
└──────┬──────────────────────────────────────────┘
       │ commands / GameSceneDelegate callbacks
┌──────▼──────────────────────────────────────────┐
│     Engine (pure Swift, @Observable)            │
│  GameEngine, EntitySpawner, SpawnTables         │
│        ▲ update(dt) each frame                  │
│  SpriteKit renderer: GameRenderScene,           │
│  EntityNodeFactory, PlayerNode (draws only)     │
└──────┬──────────────────────────────────────────┘
       │ protocol calls only
┌──────▼──────────────────────────────────────────┐
│          Services Layer                         │
│  AudioManager, HapticsManager,                  │
│  PersistenceService, LeaderboardService         │
└──────┬──────────────────────────────────────────┘
       │ reads / writes
┌──────▼──────────────────────────────────────────┐
│            Data Layer                           │
│  SwiftData (PlayerProfile, UnlockRecord, …)     │
│  UserDefaults (settings, migration flag)        │
└─────────────────────────────────────────────────┘
```

**Boundary rules:**
- `GameEngine` imports no UI framework. `GameRenderScene` and its nodes only draw; they never decide gameplay, import SwiftUI, read UserDefaults, or present view controllers.
- All upward communication from the engine goes through `GameEngineDelegate` (gameplay, audio, haptics, alerts) and `frameEvents` (one-shot visual effects for the renderer).
- All navigation goes through `AppCoordinator` — no scene calls `view?.presentScene(...)`.
- All dialogs/confirmations use SwiftUI `.alert` / `.confirmationDialog` — `Alerts.swift` is deleted.

---

## 2. Target File Structure

```
DodgeThePotholes/
├── App/
│   ├── DodgeThePotholesApp.swift        // @main, ModelContainer setup
│   ├── AppCoordinator.swift             // @Observable navigation state machine
│   └── AppContainer.swift              // DI root: constructs all services
│
├── Core/
│   ├── GameEngine/
│   │   ├── GameScene.swift              // SKScene — pure engine, no UI
│   │   ├── GameSceneDelegate.swift      // Protocol bridge: SpriteKit → ViewModel
│   │   ├── PhysicsCategory.swift        // OptionSet replacing raw UInt32 enum
│   │   ├── ContactHandler.swift         // Extracted didBegin(_:) dispatch logic
│   │   ├── SpawnManager.swift           // SKAction-based spawners (replaces Timer)
│   │   ├── SpeedController.swift        // Game speed ramp-up logic
│   │   └── AccelerometerManager.swift   // CMMotionManager wrapper
│   │
│   │   ├── Nodes/
│   │   │   ├── PlayerNode.swift         // Replaces Player.swift
│   │   │   ├── RoadBackgroundNode.swift // Replaces roadBackground.swift
│   │   │   └── HUDNode.swift            // Optional; see HUD decision in §12
│   │   │
│   │   ├── Obstacles/
│   │   │   ├── ObstacleNode.swift       // Protocol (replaces ObstacleCreate)
│   │   │   ├── PotholeNode.swift        // Replaces Pothole.swift
│   │   │   ├── BlackIceNode.swift       // Replaces blackIce.swift
│   │   │   ├── ConeNode.swift           // Replaces Cone.swift
│   │   │   ├── BarricadeNode.swift      // Replaces Barricade.swift
│   │   │   ├── PlantNode.swift          // Replaces Plant.swift
│   │   │   ├── TextMessageNode.swift    // Replaces TextMessage.swift
│   │   │   ├── MovingCarNode.swift      // Replaces MovingCar.swift
│   │   │   ├── AmbulanceNode.swift      // Replaces Ambulance.swift
│   │   │   ├── PoliceCarNode.swift      // Replaces policeCar.swift (PascalCase fix)
│   │   │   ├── MoveableObstacleNode.swift // Replaces MoveableObstacle.swift
│   │   │   ├── DogNode.swift            // Replaces Dog.swift
│   │   │   └── HumanNode.swift          // Replaces Human.swift
│   │   │
│   │   ├── PowerUps/
│   │   │   ├── PowerUpNode.swift        // Base protocol/class
│   │   │   ├── WrapPowerUpNode.swift    // Replaces PowerupWrap.swift
│   │   │   ├── OneUpPowerUpNode.swift   // Replaces PowerupOneUp.swift
│   │   │   ├── MultiplierPowerUpNode.swift // Replaces MultiplierPowerUp.swift
│   │   │   ├── MonsterTruckPowerUpNode.swift // Replaces PowerupMonsterTruck.swift
│   │   │   └── BoozePowerUpNode.swift   // Replaces Booze.swift
│   │   │
│   │   └── Collectibles/
│   │       ├── CoinNode.swift           // Replaces Coin.swift
│   │       ├── CoinPatternNode.swift    // Replaces CoinPattern.swift
│   │       └── ConePatternNode.swift    // Replaces ConePattern.swift
│   │
│   ├── Models/
│   │   ├── GameConfig.swift             // Replaces GlobalConstants.swift
│   │   ├── GameState.swift              // Enum: .menu, .playing, .paused, .gameOver
│   │   ├── PlayerState.swift            // Enum: .normal, .recovering, .monsterTruck, .drunk
│   │   ├── PowerUpState.swift           // Struct: active powerup type, timer, multiplier
│   │   ├── ObstacleType.swift           // Enum replacing [String] possibleObstacles array
│   │   ├── CarSkin.swift                // Enum: .blue (car1), .red (car2), .green (car3)
│   │   ├── Song.swift                   // Struct: filename, displayName, isUnlocked
│   │   ├── GameSound.swift              // Enum: all SFX/music file names
│   │   ├── ShopItem.swift               // Struct: id, displayName, cost, imageName
│   │   ├── Array2D.swift                // Generic 2D grid (converted from class → struct)
│   │   ├── JSONPatternLoader.swift      // Replaces Extensions.swift Dictionary method
│   │   └── SwiftData/
│   │       ├── PlayerProfile.swift      // @Model: money, highscore, selectedCar, prefs
│   │       ├── UnlockRecord.swift       // @Model: itemKey, isPurchased, purchasedDate
│   │       └── ScoreEntry.swift         // @Model: score, date, moneyEarned
│   │
│   └── Services/
│       ├── AudioManagerProtocol.swift
│       ├── AudioManager.swift           // AVAudioPlayer (music) + AVAudioEngine (SFX)
│       ├── HapticsManagerProtocol.swift
│       ├── HapticsManager.swift         // CoreHaptics
│       ├── PersistenceServiceProtocol.swift
│       ├── PersistenceService.swift     // SwiftData + UserDefaults migration bridge
│       ├── LeaderboardServiceProtocol.swift
│       └── LeaderboardService.swift     // GameKit / Game Center
│
├── UI/
│   ├── Views/
│   │   ├── MainMenuView.swift           // Replaces MenuScene.sks/.swift
│   │   ├── GameView.swift               // SpriteView + HUD overlay + effect overlays
│   │   ├── GameOverView.swift           // Replaces GameOverScene.sks/.swift
│   │   ├── SettingsView.swift           // Replaces SettingsScene.sks/.swift
│   │   ├── AudioSettingsView.swift      // Replaces AudioScene.sks/.swift
│   │   ├── CarSelectView.swift          // Replaces CarScene.sks/.swift
│   │   ├── ShopView.swift               // Replaces ShopScene.sks/.swift
│   │   └── LeaderboardView.swift        // Replaces Highscore.sks/.swift
│   │
│   ├── Components/
│   │   ├── LivesDisplayView.swift       // Row of heart/wheel icons
│   │   ├── PowerUpTimerView.swift       // Countdown bar for active powerup
│   │   ├── HUDOverlayView.swift         // Score, money, lives — overlaid on GameView
│   │   ├── DrunkOverlayView.swift       // Black overlay for Booze effect
│   │   ├── TextMessageOverlayView.swift // Rickroll lyric display (auto-dismiss 3s)
│   │   ├── CarThumbnailView.swift       // Car card with locked/unlocked state
│   │   ├── PressStart2PText.swift       // Font modifier helper
│   │   └── PixelButtonStyle.swift       // Reusable ButtonStyle
│   │
│   └── Theme/
│       ├── AppColors.swift
│       ├── AppFonts.swift               // PressStart2P font registration
│       └── AppSpacing.swift
│
└── Resources/
    ├── Assets.xcassets                  // All sprites carry over (see §10)
    ├── Fonts/
    │   └── PressStart2P.ttf
    ├── Shaders/
    │   ├── shader_water_movement.fsh
    │   ├── shader_water_reflection.fsh
    │   ├── shader1.fs
    │   └── shaderBlur.fsh
    ├── Audio/                           // All 21 audio files carry over
    └── JSON/
        ├── money_pattern1.json          // 4 coin patterns
        ├── money_pattern2.json
        ├── money_pattern3.json
        ├── money_pattern4.json
        ├── cone_pattern1.json           // 3 cone patterns
        ├── cone_pattern2.json
        └── cone_pattern3.json
```

---

## 3. Component Mapping Table

### Scenes / Screens

| Legacy File | Legacy Type | Modern File | Modern Type | Notes |
|---|---|---|---|---|
| `MenuScene.sks/.swift` | `SKScene` | `MainMenuView.swift` | `View` | Navigation via `AppCoordinator` |
| `GameScene.sks/.swift` | `SKScene` (monolith) | `GameScene.swift` + `GameViewModel.swift` | `SKScene` + `@Observable` | Scene becomes pure engine |
| `GameOverScene.sks/.swift` | `SKScene` | `GameOverView.swift` | `View` | Score passed via `GameOverViewModel` |
| `SettingsScene.sks/.swift` | `SKScene` | `SettingsView.swift` | `View` | `NavigationStack` replaces scene links |
| `AudioScene.sks/.swift` | `SKScene` | `AudioSettingsView.swift` | `View` | Binds to `SettingsViewModel` |
| `CarScene.sks/.swift` | `SKScene` | `CarSelectView.swift` | `View` | Binds to `ShopViewModel` |
| `ShopScene.sks/.swift` | `SKScene` | `ShopView.swift` | `View` | `.confirmationDialog` replaces `UIAlertController` |
| `Highscore.sks/.swift` | `SKScene` | `LeaderboardView.swift` | `View` | GameKit replaces Firebase |
| `GameViewController.swift` | `UIViewController` | `GameView.swift` | `View` wrapping `SpriteView` | `initializeUserDefaults` → `PersistenceService` migration |
| `AppDelegate.swift` | `UIApplicationDelegate` | `DodgeThePotholesApp.swift` | `@main App` | Firebase configure → GameKit authenticate |

### Player & Physics Nodes

| Legacy File | Legacy Type | Modern File | Modern Type | Notes |
|---|---|---|---|---|
| `Player.swift` | `SKSpriteNode` | `PlayerNode.swift` | `SKSpriteNode` | Polygon physics body identical; state changes via delegate |
| `roadBackground.swift` | `SKSpriteNode` | `RoadBackgroundNode.swift` | `SKSpriteNode` | Speed driven by `SpeedController` |

### Obstacle Nodes

| Legacy File | Legacy Type | Modern File | Modern Type | Notes |
|---|---|---|---|---|
| `Pothole.swift` | `SKSpriteNode` + `ObstacleCreate` | `PotholeNode.swift` | `SKSpriteNode` + `ObstacleNode` | Circular physics body; 66×65px |
| `blackIce.swift` | `SKSpriteNode` + `ObstacleCreate` | `BlackIceNode.swift` | `SKSpriteNode` + `ObstacleNode` | Renamed to PascalCase |
| `Cone.swift` | `SKSpriteNode` + `ObstacleCreate` | `ConeNode.swift` | `SKSpriteNode` + `ObstacleNode` | Grid-based; 20×20px |
| `Barricade.swift` | `SKSpriteNode` + `ObstacleCreate` | `BarricadeNode.swift` | `SKSpriteNode` + `ObstacleNode` | Grid-based; 40×40px |
| `Plant.swift` | `SKSpriteNode` + `ObstacleCreate` | `PlantNode.swift` | `SKSpriteNode` + `ObstacleNode` | Circular body; 101×100px |
| `TextMessage.swift` | `SKSpriteNode` + `ObstacleCreate` | `TextMessageNode.swift` | `SKSpriteNode` + `ObstacleNode` | Rickroll lyric sent via delegate; no `UIAlertController` |
| `MovingCar.swift` | `SKSpriteNode` + `ObstacleCreate` | `MovingCarNode.swift` | `SKSpriteNode` + `ObstacleNode` | Diagonal movement; taxi/truck/sedan textures |
| `Ambulance.swift` | `SKSpriteNode` + `ObstacleCreate` | `AmbulanceNode.swift` | `SKSpriteNode` + `ObstacleNode` | Animated siren; straight descent |
| `policeCar.swift` | `SKSpriteNode` + `ObstacleCreate` | `PoliceCarNode.swift` | `SKSpriteNode` + `ObstacleNode` | PascalCase fix; left side only |
| `MoveableObstacle.swift` | `SKSpriteNode` (base) | `MoveableObstacleNode.swift` | `SKSpriteNode` (base) | `destroy()` / `runAway()` abstract methods |
| `Dog.swift` | `MoveableObstacle` | `DogNode.swift` | `MoveableObstacleNode` | Horn interaction preserved; German Shepherd atlas |
| `Human.swift` | `MoveableObstacle` | `HumanNode.swift` | `MoveableObstacleNode` | old_man / buff_guy; same horn/death logic |
| `Pedestrian.swift` | `MoveableObstacle` (stub) | Deleted | — | Stub never implemented; remove |

### Power-up Nodes

| Legacy File | Legacy Type | Modern File | Modern Type | Notes |
|---|---|---|---|---|
| `PowerupWrap.swift` | `SKSpriteNode` | `WrapPowerUpNode.swift` | `SKSpriteNode` + `PowerUpNode` | Duration via SKAction sequence, not `Timer` |
| `PowerupOneUp.swift` | `SKSpriteNode` | `OneUpPowerUpNode.swift` | `SKSpriteNode` + `PowerUpNode` | Instant effect; max 4 lives |
| `MultiplierPowerUp.swift` | `SKSpriteNode` | `MultiplierPowerUpNode.swift` | `SKSpriteNode` + `PowerUpNode` | 30s; notifies delegate for HUD |
| `PowerupMonsterTruck.swift` | `SKSpriteNode` | `MonsterTruckPowerUpNode.swift` | `SKSpriteNode` + `PowerUpNode` | Typo `Moster` fixed |
| `Booze.swift` | `SKSpriteNode` | `BoozePowerUpNode.swift` | `SKSpriteNode` + `PowerUpNode` | Black overlay moved to SwiftUI `DrunkOverlayView` |

### Collectibles & Patterns

| Legacy File | Legacy Type | Modern File | Modern Type | Notes |
|---|---|---|---|---|
| `Coin.swift` | `SKSpriteNode` | `CoinNode.swift` | `SKSpriteNode` | Grid-based; 12.5×12.5px |
| `CoinPattern.swift` | `SKNode` manager | `CoinPatternNode.swift` | `SKNode` | JSON via `async throws`; no `DispatchQueue` |
| `ConePattern.swift` | `SKNode` manager | `ConePatternNode.swift` | `SKNode` | Same; pause logic via SpawnManager |
| `Array2D.swift` | `class` | `Array2D.swift` | `struct` | Moved to `Core/Models/` |

### Global / Infrastructure

| Legacy File | Legacy Type | Modern File | Modern Type | Notes |
|---|---|---|---|---|
| `GlobalConstants.swift` | Global `let`/`var` | `GameConfig.swift` + `PhysicsCategory.swift` | `enum` + `OptionSet` | No global mutable state |
| `Extensions.swift` | `Dictionary` extension | `JSONPatternLoader.swift` | `struct` with `async` method | `async throws` replaces `try Data(contentsOf:)` |
| `Alerts.swift` | `protocol` (UIAlertController) | **Deleted** | — | Native SwiftUI alerts throughout |
| `UserHighscore.swift` | `struct` | **Deleted** | — | Replaced by `ScoreEntry` @Model + GameKit |
| `preferences` (global `UserDefaults`) | Global `let` | `PersistenceService` | `@Observable class` | Injected, not global |
| `powerUps` (global struct) | Global `var` | `PowerUpState` in `GameViewModel` | `struct` property | Owned by ViewModel, not global |
| `leaderboardquery` (Firebase global) | Global `var` | `LeaderboardService` | `@Observable class` | GameKit replaces Firebase |
| Firebase SDK (CocoaPods) | External dependency | GameKit (built-in) | System framework | Podfile, Pods/, GoogleService-Info.plist removed |

---

## 4. ViewModel Layer Design

### `GameViewModel`
Owns all HUD-visible state. Conforms to `GameSceneDelegate` (see §5).

```swift
@Observable
@MainActor
final class GameViewModel {
    // HUD state
    var score: Int = 0
    var money: Int = 0
    var lives: Int = GameConfig.beginningLifeCount
    var playerState: PlayerState = .normal
    var activePowerUp: PowerUpState? = nil   // nil = no active powerup

    // Overlay triggers
    var isDrunkMode: Bool = false
    var showTextMessage: String? = nil       // rickroll lyric; nil = hidden

    // Injected
    let audioManager: any AudioManagerProtocol
    let hapticsManager: any HapticsManagerProtocol
    let persistenceService: any PersistenceServiceProtocol
    weak var coordinator: AppCoordinator?
}
```

### `SettingsViewModel`
```swift
@Observable
@MainActor
final class SettingsViewModel {
    var isSFXEnabled: Bool
    var isMusicEnabled: Bool
    var selectedSong: Song
    var availableSongs: [Song]
    var selectedCar: CarSkin
}
```

### `ShopViewModel`
```swift
@Observable
@MainActor
final class ShopViewModel {
    var items: [ShopItem]
    var playerMoney: Int
    var pendingPurchase: ShopItem? = nil     // drives confirmationDialog
    var errorMessage: String? = nil         // drives insufficientFunds alert
}
```

### `LeaderboardViewModel`
```swift
@Observable
@MainActor
final class LeaderboardViewModel {
    var localHighScore: Int
    var entries: [LeaderboardEntry]
    var isLoading: Bool = false
    var error: Error? = nil
}
```

### `GameOverViewModel`
```swift
@Observable
@MainActor
final class GameOverViewModel {
    let finalScore: Int
    let moneyEarned: Int
    let isNewHighScore: Bool
    let previousHighScore: Int
}
```

---

## 5. GameSceneDelegate Protocol

The sole communication path from SpriteKit upward. Every method is `@MainActor`.

```swift
// Core/GameEngine/GameSceneDelegate.swift
@MainActor
protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didUpdateScore score: Int)
    func gameScene(_ scene: GameScene, didUpdateMoney money: Int)
    func gameScene(_ scene: GameScene, didUpdateLives lives: Int)
    func gameScene(_ scene: GameScene, didChangePlayerState state: PlayerState)
    func gameScene(_ scene: GameScene, didActivatePowerUp type: PowerUpType, duration: Int)
    func gameScene(_ scene: GameScene, didDeactivatePowerUp type: PowerUpType)
    func gameScene(_ scene: GameScene, didTriggerTextMessage lyric: String)
    func gameSceneDidEnd(_ scene: GameScene, finalScore: Int, moneyEarned: Int)
    func gameSceneRequestsSound(_ sound: GameSound)
    func gameSceneRequestsHaptic(_ pattern: HapticPattern)
}
```

`GameViewModel` conforms to this protocol. Wiring in `GameView.swift`:

```swift
// UI/Views/GameView.swift
struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var scene: GameScene

    var body: some View {
        ZStack {
            SpriteView(scene: scene).ignoresSafeArea()
            HUDOverlayView(viewModel: viewModel)
            if viewModel.isDrunkMode {
                DrunkOverlayView()
            }
            if let lyric = viewModel.showTextMessage {
                TextMessageOverlayView(text: lyric)
            }
        }
        .onAppear { scene.gameDelegate = viewModel }
    }
}
```

---

## 6. Physics System

Replace the legacy `enum PhysicsCategory: UInt32` with a Swift 6-safe `OptionSet`:

```swift
// Core/GameEngine/PhysicsCategory.swift
struct PhysicsCategory: OptionSet, Sendable {
    let rawValue: UInt32

    static let none:             PhysicsCategory = []
    static let car:              PhysicsCategory = .init(rawValue: 0x1)
    static let coin:             PhysicsCategory = .init(rawValue: 0x2)
    static let horn:             PhysicsCategory = .init(rawValue: 0x4)
    static let obstacle:         PhysicsCategory = .init(rawValue: 0x8)
    static let moveableObstacle: PhysicsCategory = .init(rawValue: 0x10)
    static let multiplier:       PhysicsCategory = .init(rawValue: 0x20)
    static let wrap:             PhysicsCategory = .init(rawValue: 0x40)
    static let oneUp:            PhysicsCategory = .init(rawValue: 0x80)
    static let star:             PhysicsCategory = .init(rawValue: 0x100)
    static let recover:          PhysicsCategory = .init(rawValue: 0x200)
    static let monsterTrucker:   PhysicsCategory = .init(rawValue: 0x400)
    static let blackIce:         PhysicsCategory = .init(rawValue: 0x800)
    static let booze:            PhysicsCategory = .init(rawValue: 0x1000)
}
```

Bitmask values are **preserved identically** — physics contact routing continues to work without regression.

### ContactHandler

The legacy `didBegin(_:)` in `GameScene.swift` is ~350 lines of nested `if/else`. Extract to `ContactHandler`:

```swift
// Core/GameEngine/ContactHandler.swift
@MainActor
final class ContactHandler {
    private var processedPairs: Set<String> = []   // cleared each frame in GameScene.update()

    func handle(_ contact: SKPhysicsContact, scene: GameScene) {
        let key = contactKey(contact)
        guard !processedPairs.contains(key) else { return }
        processedPairs.insert(key)

        let mask = PhysicsCategory(rawValue:
            contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask)

        switch mask {
        case [.car, .obstacle]:          scene.carDidHitObstacle(contact)
        case [.car, .moveableObstacle]:  scene.carDidHitMoveableObstacle(contact)
        case [.car, .coin]:              scene.carDidHitCoin(contact)
        case [.car, .wrap]:              scene.carDidActivateWrap(contact)
        case [.car, .multiplier]:        scene.carDidHitMultiplier(contact)
        case [.car, .oneUp]:             scene.carDidHitOneUp(contact)
        case [.car, .star]:              scene.carDidHitStar(contact)
        case [.car, .booze]:             scene.carDidHitBooze(contact)
        case [.monsterTrucker, .obstacle]:         scene.monsterTruckDidHitObstacle(contact)
        case [.monsterTrucker, .moveableObstacle]: scene.monsterTruckDidHitMoveableObstacle(contact)
        case [.horn, .moveableObstacle]: scene.hornDidHitMoveableObstacle(contact)
        default: break
        }
    }

    func clearFrame() { processedPairs.removeAll() }
}
```

---

## 7. Audio Service

### Protocol

```swift
// Core/Services/AudioManagerProtocol.swift
@MainActor
protocol AudioManagerProtocol: AnyObject {
    var isMusicEnabled: Bool { get set }
    var isSFXEnabled: Bool { get set }
    func playBackgroundMusic(_ song: Song)
    func stopBackgroundMusic()
    func setMusicPlaybackRate(_ rate: Float)   // Booze effect: 0.5x
    func playSFX(_ sound: GameSound)
    func selectSong(_ song: Song)
}
```

### Implementation Notes (`AudioManager.swift`)
- **Background music**: `AVAudioPlayer` (replaces `SKAudioNode`). Eliminates the legacy `bgAudio.removeFromParent()` / re-add pattern for monster truck mode — just call `stop()` and start a new player.
- **SFX**: `AVAudioEngine` + per-channel `AVAudioPlayerNode` for concurrent playback. Eliminates `SKAction.playSoundFileNamed` which blocked on `waitForCompletion: true`.
- **Booze slow effect**: `player.rate = 0.5` on the music `AVAudioPlayerNode` — cleaner than `SKAction.changePlaybackRate`.
- **Monster truck**: `stopBackgroundMusic()` → `playSFX(.rampage)` → `playSFX(.monsterTruckJam)`. Restored via `selectSong(currentSong)` on `becomeCar()`.

### `GameSound` Enum (replaces string literals throughout codebase)

```swift
// Core/Models/GameSound.swift
enum GameSound: String {
    case carSkid       = "carskid.wav"
    case carHonk       = "car_honk.mp3"
    case crash         = "crash1.mp3"
    case dogWhimper    = "dog_wimper.mp3"
    case explosion     = "explosion.mp3"
    case scream        = "scream_in_pain.mp3"
    case textTone      = "text_tone.mp3"
    case ambulance     = "ambulance_s.mp3"
    case police        = "police_s.wav"
    case gameStart     = "start.wav"
    case money         = "money.aiff"
    case ohMyGod       = "oh_my_god.mp3"
    case pewPew        = "pew-pew-lei.caf"
    case rampage       = "RAMPAGE.mp3"
    case monsterTruck  = "monster_truck_jam.mp3"
    // Background music tracks
    case hotPursuit    = "hot-pursuit.wav"
    case bornLucky     = "born-lucky.wav"
    case raceDuel      = "race_duel.wav"
    case catchMe       = "catch_me.wav"
    case urbanChase    = "urban_chase.wav"
}
```

---

## 8. Persistence (SwiftData + Migration)

### SwiftData Models

**`PlayerProfile.swift`** — single record per install:
```swift
@Model
final class PlayerProfile {
    var money: Int = 0
    var highScore: Int = 0
    var selectedCarKey: String = "car1"
    var isSFXEnabled: Bool = true
    var isMusicEnabled: Bool = true
    var selectedSongFilename: String = "hot-pursuit.wav"
    @Relationship(deleteRule: .cascade) var unlocks: [UnlockRecord] = []
    @Relationship(deleteRule: .cascade) var scoreHistory: [ScoreEntry] = []
}
```

**`UnlockRecord.swift`**:
```swift
@Model
final class UnlockRecord {
    var itemKey: String           // "redcar" | "greencar" | "life" | "tank" | song filename
    var isPurchased: Bool = false
    var purchasedDate: Date?
}
```

**`ScoreEntry.swift`** (local run history + offline leaderboard fallback):
```swift
@Model
final class ScoreEntry {
    var score: Int
    var moneyEarned: Int
    var date: Date
}
```

### UserDefaults Migration

`PersistenceService` performs a **one-time migration** on first v2 launch:

| Legacy `UserDefaults` Key | SwiftData Destination |
|---|---|
| `"money"` | `PlayerProfile.money` |
| `"highscore"` | `PlayerProfile.highScore` |
| `"car"` | `PlayerProfile.selectedCarKey` |
| `"sfx"` | `PlayerProfile.isSFXEnabled` |
| `"music"` | `PlayerProfile.isMusicEnabled` |
| `"song_selected"` | `PlayerProfile.selectedSongFilename` |
| `"redcar"` (Bool) | `UnlockRecord(itemKey: "redcar")` |
| `"greencar"` (Bool) | `UnlockRecord(itemKey: "greencar")` |
| `"life"` (Bool) | `UnlockRecord(itemKey: "life")` |
| `"tank"` (Bool) | `UnlockRecord(itemKey: "tank")` |
| `"songs"` (Dict) | Multiple `UnlockRecord` instances |

Migration guard flag: `UserDefaults.standard.bool(forKey: "v2_migrated")`. Set to `true` after migration completes.

### Shop Pricing (replacing scattered global `let` constants)

Centralized in `GameConfig`:
```swift
extension GameConfig {
    enum ShopCost: Int {
        case car   = 500
        case life  = 1000
        case tank  = 5000
        case song  = 500
    }
}
```

---

## 9. Spawn System

The legacy code uses four retained `Timer` instances (`gameTimer`, `bgTimer`, `envTimer`, `powerUpTimer`). These fire on a `RunLoop` thread independent of SpriteKit, require manual `invalidate()` in `loseLife()`, and leak when the scene is deallocated.

### `SpawnManager` using SKAction keys

```swift
// Core/GameEngine/SpawnManager.swift
@MainActor
final class SpawnManager {
    private enum Key {
        static let obstacle    = "spawn_obstacle"
        static let environment = "spawn_env"
        static let powerUp     = "spawn_powerup"
    }

    private weak var scene: GameScene?
    private(set) var currentObstacleInterval: TimeInterval = 1.75

    func startAllSpawners() {
        scheduleObstacleSpawner(interval: currentObstacleInterval)
        scheduleEnvironmentSpawner()
        schedulePowerUpSpawner()
    }

    func stopAllSpawners() {
        scene?.removeAction(forKey: Key.obstacle)
        scene?.removeAction(forKey: Key.environment)
        scene?.removeAction(forKey: Key.powerUp)
    }

    /// Called by SpeedController when game speed changes.
    func setObstacleInterval(_ interval: TimeInterval) {
        currentObstacleInterval = interval
        scheduleObstacleSpawner(interval: interval)  // replaces running action
    }

    private func scheduleObstacleSpawner(interval: TimeInterval) {
        let action = SKAction.repeatForever(.sequence([
            .run { [weak self] in self?.scene?.spawnObstacle() },
            .wait(forDuration: interval)
        ]))
        scene?.run(action, withKey: Key.obstacle)
    }
    // Similar for environment (1.0s) and powerup (5.0s) spawners
}
```

**Benefits over legacy `Timer`**:
- Auto-pauses when `scene.isPaused = true` (pause menu)
- Auto-stops when scene is removed from the view hierarchy
- No `invalidate()` calls needed in `loseLife()`
- Interval updates are atomic (new `run(_, withKey:)` replaces old)

### `SpeedController`

Replaces the `bgTimer` (10s interval speed ramp-up):

```swift
@MainActor
final class SpeedController {
    static let startSpeed: TimeInterval = 2.0
    static let minSpeed: TimeInterval   = 0.2
    static let rampInterval: TimeInterval = 10.0
    static let rampStep: TimeInterval   = 0.1

    private(set) var currentSpeed: TimeInterval = startSpeed

    func startRamp(in scene: GameScene) {
        let rampAction = SKAction.repeatForever(.sequence([
            .wait(forDuration: rampInterval),
            .run { [weak self, weak scene] in
                guard let self, let scene else { return }
                self.currentSpeed = max(self.currentSpeed - rampStep, minSpeed)
                scene.spawnManager.setObstacleInterval(self.currentSpeed)
                scene.roadBackground.updateSpeed(self.currentSpeed)
            }
        ]))
        scene.run(rampAction, withKey: "speed_ramp")
    }
}
```

---

## 10. Asset Migration

### Carry Over Unchanged
All of the following move directly to `Resources/` with no modifications:

**Sprite Atlases (23 total):**
`Ambulance`, `Car1_Left`, `Car1_Right`, `Car2_Left`, `Car2_Right`, `Car3_left`, `Car3_right`, `German_Shepherd_Bark`, `German_Shepherd_Run`, `German_Shepherd_Walk`, `old_man_dead`, `old_man_jump`, `old_man_walk`, `buff_guy_jump`, `buff_guy_walk`, `Police`, `sedan_left`, `sedan_right`, `taxi_left`, `taxi_right`, `truck_left`, `truck_right`, `Particle Sprite Atlas`

**Single Images (~60):** All pothole/cone/plant/powerup/UI/vehicle images including `car1`, `car2`, `car3`, `MonsterTruck`, `tank`, `pothole1/2/3`, `ice`, `cone`, `barricade`, `beer`, `dollar`, `oneup`, `pow_wrap`, `pow_x2`, `pow_x3`, `star`, `phone`, `tree1`, `bush1`, `road_long`, `wheel`, all button images.

**Audio (21 files):** All `.mp3`, `.wav`, `.aiff`, `.caf` files.

**JSON Patterns (7 files):** `money_pattern1-4.json`, `cone_pattern1-3.json`.

**Shaders (4 files):** `shader_water_movement.fsh`, `shader_water_reflection.fsh`, `shader1.fs`, `shaderBlur.fsh`.

**Font:** `PressStart2P.ttf`

**Particle emitter:** `Explosion.sks` (referenced by `MonsterTruckPowerUpNode`)

### Requires Update / Cleanup
- `Selected.png` and `newGameButton.png` (loose files at root of legacy source) → move into `Assets.xcassets`
- Audit all sprites for missing `@3x` variants; export from source if available
- `AppIcon.appiconset` — verify all sizes present for iOS 17 requirements (may need 1024×1024 only with new Xcode)
- `German_Shepherd/Contents.json` — missing `Contents.json` for the atlas folder itself (present in legacy; verify copy)

### Remove Entirely
- `GoogleService-Info.plist` — Firebase config; no longer needed
- All `.sks` scene files except `Explosion.sks` — gameplay scenes become SwiftUI Views
- `Actions.sks`, `Starfield.sks`, `carHorn.sks` — inline or recreate as SKAction in code

---

## 11. Implementation Phases

### Phase 1 — Foundation
**Goal:** Compiling skeleton, no gameplay. Everything the rest of the app depends on.

- [ ] `DodgeThePotholesApp.swift` with `@main`, empty `ModelContainer` (all three `@Model` types)
- [ ] `AppCoordinator.swift` — all routes defined, only `MainMenuView` renders (stub)
- [ ] `AppContainer.swift` — constructs no-op stub implementations of all services
- [ ] `PhysicsCategory.swift` as `OptionSet`
- [ ] `GameConfig.swift` — all constants from `GlobalConstants.swift`
- [ ] `Array2D.swift` as `struct`, moved to `Core/Models/`
- [ ] `SwiftData` models: `PlayerProfile`, `UnlockRecord`, `ScoreEntry`
- [ ] `AppFonts.swift` — register `PressStart2P.ttf` via `CTFontManagerRegisterFontsForURL`
- [ ] `PixelButtonStyle.swift` — basic styled button for main menu

**Milestone:** App launches; main menu shows "Dodge The Potholes" in PressStart2P font.

---

### Phase 2 — Settings, Shop, Car Select
**Goal:** All non-game screens functional with real persistence.

- [ ] `PersistenceService.swift` — SwiftData CRUD + UserDefaults migration function
- [ ] `SettingsViewModel.swift` — reads/writes via `PersistenceService`
- [ ] `AudioManager.swift` — `AVAudioPlayer` for music, `AVAudioEngine` for SFX
- [ ] `AudioSettingsView.swift` — music on/off, SFX on/off, song cycle buttons
- [ ] `CarSelectView.swift` — three car options, locked state from `UnlockRecord`
- [ ] `ShopViewModel.swift` — purchase flow with `pendingPurchase` / `confirmationDialog`
- [ ] `ShopView.swift` — car, life, tank, song items
- [ ] `HapticsManager.swift` — CoreHaptics patterns for UI feedback

**Milestone:** Full settings/shop flow end-to-end; purchasing a car unlocks it in car select; data persists across launches.

---

### Phase 3 — Core Game Engine
**Goal:** `GameScene` runs the full game; `GameSceneDelegate` fires correctly.

- [ ] `GameSceneDelegate.swift` — finalize protocol (critical API; must stabilize before Phase 4)
- [ ] `PlayerNode.swift` — polygon physics body, `spinOut()`, `recover()`, `becomeMonsterTruck()`, `becomeCar()`
- [ ] `AccelerometerManager.swift` — `CMMotionManager` wrapper, publishes `xAcceleration`
- [ ] `RoadBackgroundNode.swift` — continuous SKAction scrolling
- [ ] All 13 obstacle nodes (`PotholeNode` → `HumanNode`)
- [ ] All 5 powerup nodes (`WrapPowerUpNode` → `BoozePowerUpNode`) — timers via SKAction sequences
- [ ] `CoinNode.swift`, `CoinPatternNode.swift`, `ConePatternNode.swift` — JSON via `async throws`
- [ ] `SpawnManager.swift` — SKAction-keyed spawners
- [ ] `SpeedController.swift` — 10s ramp loop
- [ ] `ContactHandler.swift` — dispatch table replacing 350-line `didBegin` switch
- [ ] `GameScene.swift` — wires all of the above; zero UI, zero UserDefaults access

**Milestone:** `GameScene` added to a test harness plays the full game; all collision types handled; all delegate callbacks fire.

---

### Phase 4 — Game View Layer
**Goal:** SwiftUI wraps the game with all overlay effects.

- [ ] `GameViewModel.swift` — conforms to `GameSceneDelegate`
- [ ] `GameView.swift` — `SpriteView` + `HUDOverlayView` + `DrunkOverlayView` + `TextMessageOverlayView`
- [ ] `HUDOverlayView.swift` — score, money, lives, active powerup timer
- [ ] `DrunkOverlayView.swift` — `TimelineView` pulsing black overlay
- [ ] `TextMessageOverlayView.swift` — slide-up lyric, auto-dismiss after 3s
- [ ] `LivesDisplayView.swift`, `PowerUpTimerView.swift`
- [ ] Wire `AppCoordinator` navigation: main menu → game → game over → menu

**Milestone:** Full game loop works: tap "New Game" → game plays → run out of lives → GameOverView shown.

---

### Phase 5 — Leaderboard & Game Over
**Goal:** Score submission and leaderboard display.

- [ ] `LeaderboardService.swift` — `GKLeaderboard` authentication, score submission, fetch top-10
- [ ] `LeaderboardView.swift` — async fetch with local `ScoreEntry` fallback
- [ ] `GameOverView.swift` — new-high-score flash animation (SwiftUI), score, money earned, buttons
- [ ] `GameOverViewModel.swift` — created by `GameViewModel.gameSceneDidEnd`
- [ ] `PersistenceService` update: save `ScoreEntry` and update `PlayerProfile.highScore` on game over

**Milestone:** After game over: score saved locally, submitted to Game Center, leaderboard view shows results.

---

### Phase 6 — Polish & Migration
**Goal:** Legacy code removed; Swift 6 compliance; shipped.

- [ ] Run `PersistenceService.migrateFromLegacyIfNeeded()` on first launch
- [ ] Remove all `.sks` scene files (except `Explosion.sks`)
- [ ] Remove Firebase (`Podfile`, `Podfile.lock`, `Pods/`, `GoogleService-Info.plist`)
- [ ] Delete legacy Swift files: all files in `legacy_source/` from production target
- [ ] Audit and fix all `@Sendable`/actor isolation warnings (Swift 6 strict concurrency)
- [ ] Replace any remaining `DispatchQueue.main.async` with `await MainActor.run {}`
- [ ] Performance: profile on iPhone 12 minimum; target stable 60fps
- [ ] One-time in-app alert informing users that global leaderboard has reset (Firebase → Game Center)

---

## 12. Key Risks & Decisions

### Risk 1 — Drunk Mode Overlay (resolved)
**Legacy**: `SKSpriteNode` ("drinkingGoggles") with pulsing `alpha` SKAction added to the SpriteKit scene at `zPosition = 3`.
**Modern**: SwiftUI `DrunkOverlayView` using `TimelineView(.animation)` for frame-accurate pulsing. `GameViewModel.isDrunkMode` drives visibility. This is cleaner and avoids managing zPosition layering in SpriteKit.
**Risk**: SwiftUI animation timing may differ slightly from SKAction. Use `TimelineView(.animation(minimumInterval: 1.0))` to match the legacy 1-second fade cycle.

### Risk 2 — TextMessage Rickroll (behavior change)
**Legacy**: `UIAlertController.actionSheet` from inside `GameScene` — **blocks gameplay** while shown.
**Modern**: Non-blocking `TextMessageOverlayView` slides in from bottom, auto-dismisses after 3 seconds. `GameSceneDelegate.gameScene(_:didTriggerTextMessage:)` fires; `GameViewModel.showTextMessage` drives the overlay.
**Decision**: Accept as intentional UX improvement. The alert-based pause was likely a bug, not a feature.

### Risk 3 — Firebase → Game Center (data loss)
**Legacy**: Global leaderboard stored scores keyed by `UIDevice.current.identifierForVendor`.
**Modern**: `GKLeaderboard` — player identity is `GKLocalPlayer`.
**Decision**: Accept score history reset as a version boundary. Show one-time in-app notification: *"The global leaderboard has been reset in this update. Sign in to Game Center to compete again!"*

### Risk 4 — `oneCollision` Race Condition (resolved)
**Legacy**: `var oneCollision: Bool` flag to prevent double-processing contacts. Prone to Swift 6 data race violations when physics callbacks arrive within the same frame.
**Modern**: `ContactHandler.processedPairs: Set<String>` tracks contact pair keys for the current frame, cleared in `GameScene.update()`. Thread-safe because `GameScene` is `@MainActor`.

### Risk 5 — Swift 6 Sendable in SpriteKit Nodes
`SKSpriteNode` is not `Sendable`. Cross-actor calls from SpriteKit to SwiftUI must go through the `@MainActor`-annotated `GameSceneDelegate` only. Annotate `GameScene` as `@MainActor`. Never pass node references across actor boundaries — pass value types (Int, enum cases, String) instead.

### Decision — HUD Location
Two options: (A) `HUDNode` inside SpriteKit scene, (B) `HUDOverlayView` in SwiftUI ZStack.
**Chosen: Option B (SwiftUI HUD).** The `PressStart2P` font renders more cleanly in SwiftUI's text system than via `SKLabelNode`. The one-frame latency from `GameSceneDelegate` updates is imperceptible for a score counter. SwiftUI animations for powerup timers are higher quality than SKAction label effects.

### Decision — ConePattern Timer Pause
**Legacy**: `ConePattern.addCones()` calls `gameTimer.invalidate()` to pause obstacle spawning during a traffic zone, then schedules a new `gameTimer` after the cone field clears.
**Modern**: `SpawnManager.stopObstacleSpawner()` / `startObstacleSpawner()`. Called from `ConePatternNode` via a delegate method or directly from `GameScene` after the pattern's SKAction sequence completes. No Timer to invalidate — simply remove and re-add the keyed SKAction.

### Decision — Accelerometer Thread Safety
**Legacy**: `CMMotionManager.startAccelerometerUpdates(to: .main)` updates are on main thread directly.
**Modern**: `AccelerometerManager` wraps `CMMotionManager` and publishes `xAcceleration: Double` as an `@Observable` property updated on `@MainActor`. `GameScene.didSimulatePhysics()` reads this value directly since it also runs on main thread.
