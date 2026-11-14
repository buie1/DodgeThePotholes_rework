# Dev Mode

Tools for dropping the game into an exact situation to test it, by hand or from a
script. **Debug builds only:** everything is behind `#if DEBUG`, so none of it ships in
a Release / App Store build. Extending it to TestFlight builds is on the roadmap.

## Scenarios

A `DevScenario` (`DodgeThePotholes/Debug/DevScenario.swift`) sets up a run. Every field
is optional; an empty scenario is a normal run.

| Field | Meaning |
|-------|---------|
| `seed` | Seeds the spawners: the same seed plays the same road at any frame rate |
| `obstacles`, `environment`, `powerUps` | Replacement spawn pools in `tuning.json`'s row format. Unset keeps the normal pool; `[]` spawns nothing |
| `startElapsed` | Starts the speed ramp as if this many seconds had been played |
| `startPowerUps` | Active from the first frame: `wrap`, `monsterTruck`, `booze`, `oneUp`, `x2`, `x3` |
| `lives` | Starting lives |
| `godMode` | Hits flash the car but never cost a life |
| `timeScale` | `0.5` is slow motion, `2` is double speed |
| `autopilot` | A simple bot drives and honks (`Debug/Autopilot.swift`) |
| `hitboxes` | Outlines every hit box on screen |
| `bank`, `unlockAll` | Money and unlocks for the throwaway profile |
| `useRealProfile` | Play on your real save. Runs are then **not recorded** |

**Presets** (all seed 42): `godCruise`, `monsterTruck`, `potholeRain`, `lateGame`,
`coinShower`, `textMessages`, `trafficZone`.

**Rules for dev runs:**
- They never submit to Game Center.
- By default they use a throwaway in-memory profile, so nothing touches your real save.

## The DEV menu

In debug builds the main menu has a red **DEV** button (top right). It opens a menu where
you can:

- **Set up a run:** pick a preset or edit a scenario (seed, god mode, autopilot, time scale,
  starting speed and lives, power-ups to start with, which obstacles / roadside items /
  power-ups spawn, throwaway bank and unlocks).
- **Start Run:** plays the scenario on its own throwaway profile, or on your real one if
  "Use real profile" is on. Closing the run returns you to the DEV menu.
- **Edit your real profile:** add $10,000, unlock everything, or reset progress (keeps
  sound settings). Each asks for confirmation first.

The `-devMenu` launch argument opens the menu on launch.

## The in-run DEV panel

During any run in a debug build, a red **DEV** button under the lives opens a panel at the
top of the screen. It stays at the top so it never hides your car.

| Control | What it does |
|---------|--------------|
| Readout | Seconds of play, current travel duration, frame rate, and seed |
| **God** | Hits flash the car but cost nothing |
| **Autopilot** | The bot drives |
| **Hitboxes** | Draws the exact rectangles the engine collides: player blue, obstacles red, power-ups yellow, coins green, horns purple. The player's box covers only the front half of the car, as in the original game |
| Time scale | 0.25× to 4× |
| **Pause / Step** | Pause, then advance one frame per tap |
| **+30 s** | Jumps the speed ramp forward 30 seconds |
| **Obstacle ▾ / Pickup ▾** | Spawns any obstacle or pickup now |
| **Activate ▾** | Starts any power-up now |

**Using the panel on a normal run:** that run is marked dev-adjusted, so it is **not
recorded or submitted**. The next untouched run counts normally.

The `-devOverlay` launch argument opens the panel at the start of a run.

## Launching a scenario

The launch arguments skip the menu and start the run straight away:

```
-devScenario lateGame
-devScenarioJSON '{"seed": 7, "godMode": true, "obstacles": [{"spawn": "dog", "weight": 1}]}'
-devAutopilot          (adds the autopilot to either)
```

**In Xcode:**
1. Open Product → Scheme → Edit Scheme → Run → Arguments.
2. Add the flag and its value as two separate arguments, e.g. `-devScenario` and `lateGame`.
3. Untick them to play normally.

A typo in a preset, spawn or power-up name stops the app with a message listing the valid
names.

## Simulator runs: `scripts/dev-run.sh`

```sh
scripts/dev-run.sh monsterTruck                    # 15 s, 3 screenshots
scripts/dev-run.sh potholeRain 30 --shots 5 --autopilot
scripts/dev-run.sh '{"startPowerUps": ["booze"], "autopilot": true}' 10
scripts/dev-run.sh lateGame 20 --no-build          # reuse the last build
scripts/dev-run.sh '{"hitboxes": true}' 10 --overlay   # with the DEV panel open
```

The script:
1. Builds the app, using the booted simulator or booting an iPhone 17.
2. Launches the scenario.
3. Takes screenshots spread over the run.
4. Copies out the event log.

Results go to `build/dev-runs/<timestamp>-<name>/`, which is git-ignored:
- `shot-N.png`
- `devlog.jsonl`
- `run.txt`

### The event log

`devlog.jsonl` has one JSON object per line, each with `t` (seconds of play) and `event`:

| Event | Fields |
|-------|--------|
| `runStart` | `seed`, `godMode`, `timeScale`, `autopilot`, `startElapsed` |
| `snapshot` (≈ every second) | `score`, `money`, `lives`, `state`, `x`, `travelDuration`, `obstacles`, `powerUps`, `coins` |
| `lives` | `lives` |
| `playerState` | `state` |
| `powerUpOn` / `powerUpOff` | `type` (and `seconds`) |
| `alert`, `textMessage` | `message` / `index` |
| `sound` | `name` (coin pickups left out); shows hits, explosions, honks |
| `gameOver` | `score`, `money` |

The log starts fresh each app launch.

## Headless runs (tests)

`DodgeThePotholesTests/ScenarioRunner.swift` runs a scenario without a screen at a fixed
frame rate and returns a summary (`elapsed`, `score`, `money`, `livesLost`, `isGameOver`):

```swift
let summary = ScenarioRunner.run(DevScenario(seed: 3, autopilot: true), seconds: 120)
```

Use it for balance checks that would take minutes of real play.

## Engine hooks

`GameEngine` has DEBUG-only hooks (bottom of `GameEngine.swift`):

| Hook | Effect |
|------|--------|
| `debug.godMode`, `debug.timeScale`, `debug.autopilot` | Same as the scenario fields |
| `spawnNow(_:)` | Spawns any obstacle or power-up roll now |
| `activatePowerUp(_:)` | Starts a power-up |
| `setLives(_:)` | Sets the remaining lives |
| `fastForwardSpeedRamp(by:)` | Jumps the speed ramp forward |
| `insert(_:)` | Places an entity at an exact position |
