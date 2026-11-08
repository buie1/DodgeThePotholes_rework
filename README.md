# DodgeThePotholes

A pixel-art arcade driving game for iPhone. Tilt (or drag) to steer down an endless road, dodging
potholes, black ice, cones, barricades, traffic, dogs and pedestrians. Tap to honk and scare
animals and people out of the way, grab coins and power-ups (screen wrap, coin multipliers, the
monster truck, extra lives — and avoid the booze), then spend your coins in the shop on new
cars, songs, an extra life or the tank.

This is a modern rewrite of the original 2016 SpriteKit/Firebase game in SwiftUI.

## Requirements

- Xcode 26 (Swift 6 language mode)
- iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

The Xcode project is generated from `project.yml`. Regenerate it after cloning and whenever
you add or remove files:

```sh
xcodegen generate
open DodgeThePotholes.xcodeproj
```

## Build & test

```sh
xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Tilt steering needs a real device; in the simulator, drag to steer.

## Architecture

SwiftUI views observe `@Observable` view models. `GameViewModel` drives a pure-Swift
`GameEngine` (spawning, AABB collisions, power-ups, horn) in a fixed 750-unit-wide world,
and a SpriteKit `GameRenderScene` ticks the engine's clock and draws its state. Audio, haptics, motion,
persistence (SwiftData) and the leaderboard (GameKit) sit behind protocols and are
injected, so view models are tested with mocks. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
and [docs/MIGRATION_PLAN.md](docs/MIGRATION_PLAN.md).

```
DodgeThePotholes/
  App/          entry point
  Core/         GameEngine, Models (+ SwiftData), Rendering (SpriteKit), Services
  UI/           view models, Views, Components, Theme
  Resources/    sprites, audio, fonts, tile patterns
DodgeThePotholesTests/
```

## Game Center (going live)

The leaderboard is offline-first: until Game Center is configured, sign-in fails quietly and
the Leaderboard screen shows the player's own best runs. To turn on the global leaderboard:

1. Set `DEVELOPMENT_TEAM` in `project.yml` and run `xcodegen generate`.
2. Add the Game Center capability (`com.apple.developer.game-center` entitlement) to the app target.
3. In App Store Connect, create the app and enable Game Center.
4. Add a classic, all-time, high-score-first leaderboard with ID `dodgethepotholes.highscore`
   (`GameConfig.leaderboardID`).
5. Sign in to a Game Center sandbox account on a device and play a run to see your score.
