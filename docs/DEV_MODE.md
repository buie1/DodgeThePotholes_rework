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
| `chaseNearMisses` | The bot drives close on purpose to chain near-misses (`Autopilot.comboChaser`), like a player building a combo |
| `hitboxes` | Outlines every hit box on screen |
| `bank`, `unlockAll` | Money and unlocks for the throwaway profile |
| `useRealProfile` | Play on your real save. Runs are then **not recorded** |

**Presets** (all seed 42): `godCruise`, `monsterTruck`, `potholeRain`, `lateGame`,
`coinShower`, `textMessages`, `trafficZone`, `nearMiss` (the combo-chasing bot weaving
through potholes, traffic and dogs, with hitboxes).

**Rules for dev runs:**
- They never submit to Game Center.
- By default they use a throwaway in-memory profile, so nothing touches your real save.

## The DEV menu

In debug builds the main menu has a red **DEV** button (top right). It opens a menu with,
from the top:

- **Real Profile:** your actual saved progress, which the Shop and the game's BEST use.
  - **Bank:** +$1,000 / +$10,000 / +$100,000, or "Set bank to…". Adding money is instant.
  - **High score:** "Set high score to…" or "Reset high score". Lowering it asks first.
    Each run re-reads it, so a new value shows as BEST in the next game.
  - **Unlock everything** and **Reset progress** (keeps sound settings). Both ask first.
- **Preset and scenario:** seed, god mode, autopilot, time scale, starting speed and lives,
  power-ups to start with, and which obstacles / roadside items / power-ups spawn.
- **Dev-Run Profile:** the **dev-run** bank and unlocks. These only apply to the throwaway
  profile a dev run plays on, and **never** reach the Shop. To give yourself money to spend,
  use Real Profile.
- **Start Run:** plays the scenario on its throwaway profile, or on your real one if
  "Use real profile" is on (not recorded). Closing the run returns you to the DEV menu.

The `-devMenu` launch argument opens the menu on launch.

## The in-run DEV panel

During any run in a debug build, a red **DEV** button under the lives opens a panel at the
top of the screen. It stays at the top so it never hides your car.

| Control | What it does |
|---------|--------------|
| Readout | Seconds of play, current travel duration, combo (`x2 (4)` = multiplier and chain), frame rate, and seed |
| **God** | Hits flash the car but cost nothing |
| **Autopilot** | The bot drives |
| **Hitboxes** | Draws the exact rectangles the engine collides: player blue, obstacles red, power-ups yellow, coins green, horns purple, and the near-miss band faint cyan. The player's box covers only the front half of the car, as in the original game |
| Time scale | 0.25× to 4× |
| **Pause / Step** | Pause, then advance one frame per tap |
| **+30 s** | Jumps the speed ramp forward 30 seconds |
| **Obstacle ▾ / Pickup ▾** | Spawns any obstacle or pickup now |
| **Activate ▾** | Starts any power-up now |

**Using the panel on a normal run:** that run is marked dev-adjusted, so it is **not
recorded or submitted**. The next untouched run counts normally.

The panel and the HUD sit above the steering layer. Panel controls get their own taps
without honking or steering, while touches on open road still steer and honk.

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

### Short effects: video and contact sheets

A screenshot rarely catches a 0.3 s shake or flash. For those, record the run and turn a
moment into a contact sheet:

```sh
scripts/dev-run.sh potholeRain 9 --shots 1 --video   # also writes run.mp4
grep '"sound"' build/dev-runs/<run>/devlog.jsonl      # find the moment, e.g. t 5.11
scripts/dev-frames.sh build/dev-runs/<run> 5.11 0.8   # frames-5.11.png: 0.8 s at 15 fps
```

Video recording needs `ffmpeg` (`brew install ffmpeg`). Log times line up with the
video through the `clock` field on snapshots.

### The event log

`devlog.jsonl` has one JSON object per line, each with `t` (seconds of play) and `event`:

| Event | Fields |
|-------|--------|
| `runStart` | `seed`, `godMode`, `timeScale`, `autopilot`, `startElapsed` |
| `snapshot` (≈ every second) | `score`, `money`, `lives`, `state`, `x`, `travelDuration`, `obstacles`, `powerUps`, `coins`, `combo`, `multiplier`, `nearMisses`, `smashed`, `scared`, `clock` (Unix time, to align with a recording) |
| `bonus` | `kind` (`nearMiss`, `smash`, `zone`), `points` (multiplied), `multiplier`, `chain` |
| `lives` | `lives` |
| `playerState` | `state` |
| `powerUpOn` / `powerUpOff` | `type` (and `seconds`) |
| `alert`, `textMessage` | `message` / `index` |
| `sound` | `name` (coin pickups left out); shows hits, explosions, honks |
| `haptic` | `pattern` (coin ticks left out), since the simulator can't play haptics |
| `gameOver` | `score`, `money` |

The log starts fresh each app launch.

## UI tests

`DodgeThePotholesUITests` taps through the app like a person (XCUITest):

| File | Covers |
|------|--------|
| `MenuAndShopUITests` | every menu screen opens and returns; Shop insufficient-funds and already-purchased alerts; extra life used next run; only owned cars selectable; audio settings stick |
| `GameFlowUITests` | NEW GAME starts a run; game over → Play Again → Main Menu |
| `DevModeUITests` | DEV menu: add money / set bank reach the Shop, set high score shows as BEST, unlock everything + reset progress, a preset starts a dev run |
| `DevPanelUITests` | in-game panel: chips match the scenario and toggle; time scale, pause/step, +30 s and spawn menus work without honking; open road still steers and honks |

The tests run with `-freshProfile`, which starts the app on an empty throwaway profile
without starting a scenario, so they never touch real saves. `-devBank <amount>` funds that
profile. `-skipOnboarding` starts past the first-launch Tilt/Drag choice and the tutorial
(dev-scenario launches skip them too); `launchApp(onboarding: true)` leaves it out to test
them. Shared steps live in `UITestSupport.swift`.

```sh
# Everything (unit + UI tests; the UI tests take a few minutes)
xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 17' test
# Only the fast unit tests
xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:DodgeThePotholesTests
# Only the UI tests
xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:DodgeThePotholesUITests
```

Elements the tests use carry accessibility identifiers (`dev.button`, `dev.bank`,
`dev.add10000`, `dev.setBank`, `dev.highScore`, `shop.bank`, `hud.best`, `dev.readout`…).
The DEV panel readout also shows the time scale, the car's x position and a honk count, so
a test can tell a panel tap from a road tap.

## Headless runs (tests)

`DodgeThePotholesTests/ScenarioRunner.swift` runs a scenario without a screen at a fixed
frame rate and returns a summary (`elapsed`, `score`, `money`, `livesLost`, `isGameOver`):

```swift
let summary = ScenarioRunner.run(DevScenario(seed: 3, autopilot: true), seconds: 120)
```

Use it for balance checks that would take minutes of real play; pass `pilot:` to drive
with a specific `Autopilot` (e.g. `.comboChaser`). `ComboBalanceTests` uses it to keep
combos in their intended range.

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
