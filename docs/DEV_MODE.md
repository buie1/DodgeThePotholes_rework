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
