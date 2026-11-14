# DodgeThePotholes — Product Roadmap

Goal: a game that is **fun, sticky, revenue-generating, and cheap to maintain**.
Approved 2026-11-13 after a design interview. Each item ships one step at a time
(stage → review in Xcode → commit).

## Status

| Item | Status |
|------|--------|
| #0 Shared groundwork | ✅ Done: seeded RNG (`44798f8`), tuning JSON (`ba08e27`), catalog JSON (`15a10d5`) |
| Dev mode and test hooks | 🚧 In progress (see `docs/DEV_MODE.md` once written) |
| #1–#11 | Not started; paused until dev mode lands |

## Decisions

- **Time:** about 10–20 hrs/week (serious part-time). Live ops are possible but kept light.
- **Revenue:** hybrid. Rewarded ads, capped interstitials, StoreKit 2 in-app purchases.
- **Art:** keep pixel art and upgrade it. Asset packs now, commission hero art later.
- **Tone:** softened for a broad audience (aim for a 4+/9+ rating and better ad fill).
- **Backend:** Firebase (Analytics, Remote Config, Crashlytics), plus AdMob.

## Where the game started

The design is the original 2016 one:
- **Pacing:** one endless mode with a linear speed ramp (2.0 s → 0.2 s, −0.1 every 10 s,
  maxed at about 3 min).
- **Scoring:** survival time only.
- **Meta:** a 9-item shop you can buy out for about 10.5k coins.
- **Missing:** retention hooks, monetization and production tooling.

Foundations to build on:
- The pure-Swift `GameEngine` with its `GameEngineDelegate` / `GameEvent` stream.
- Protocol-injected services.
- JSON tuning and catalog (`Resources/Config/`).
- `UnlockRecord` with arbitrary item keys.
- The mock-based test suite.

---

## 0. Shared groundwork ✅
- **Config and catalogs as JSON:** `Resources/Config/tuning.json` (`GameTuning`) and
  `catalog.json` (`GameCatalog`). Remote Config (#10) can override them later.
- **Seeded RNG:** one `SplitMix64` stream per spawner, so a seeded road is identical at any
  frame rate.

## 1. Near-misses and combos: big skill ceiling
- A near-miss band around each obstacle AABB gives a bonus and raises a combo multiplier
  **x1 → x5**. Honking a dog or pedestrian away and coin chains also feed the combo. A hit
  resets it. Combos can multiply score 3–5x, so risky play clearly beats safe play.
- Floating "NEAR MISS +50 x3" text and a combo meter in the HUD.
- **Where:** collision pass in `GameEngine.swift`; new delegate callback `didScoreBonus`;
  tuning in JSON; `HUDOverlayView.swift`.

## 2. Missions → XP → player level → unlocks
- 3 active missions at a time ("Honk 5 dogs away", "300 coins in one run", "Reach the
  Highway"). Finishing one gives XP. Player levels unlock cars, cosmetics and shop tiers.
- **Where:** `MissionService` protocol + SwiftData `MissionProgress`, `PlayerProfile.xp/level`.
  Missions are defined in JSON.

## 3. Daily run: the first run counts, replays are practice
- Today's date seeds the spawner, so everyone drives the same road. The **first** daily run
  is the leaderboard entry. Replays are unlimited practice: they earn coins, XP and mission
  progress but never change the entry. A streak counter gives escalating rewards.
- The daily run uses a **stock car with no perks**.
- **Where:** seeded RNG (#0); daily Game Center leaderboard (recurring) next to
  `GameConfig.leaderboardID`; `PlayerProfile.lastDailyDate/streak`.

## 4. Zones in a fixed order and a sawtooth difficulty curve
- **Downtown → Suburbs → Highway → Winter Night**, about 45 s each, in the same order every
  run. Each zone has its own road tiles, obstacle weights and a signature hazard. Difficulty
  ramps within a zone and eases briefly at each transition with a "Now entering…" banner.
- **Where:** zone config in JSON; spawner reads the current zone's weights; tiles/tint in
  `GameRenderScene.swift`.

## 5. Onboarding, control choice, instant retry
- **First launch:** a "Tilt or Drag?" choice screen, then an interactive scripted tutorial
  (steer → honk the dog → grab the coin → a power-up). The first run is tuned easier.
- Settings: switch controls anytime, and recalibrate tilt.
- "Play Again" restarts in under 1 s. Auto-pause when the app goes to the background, with a
  3-2-1 countdown on resume.

## 6. Bigger car and cosmetic catalog with economy-only perks
- 20–40 cars in rarity tiers. Perks affect **economy only** (+5% coins, +10% XP). They never
  touch score, handling or survival, and the daily run disables them.
- Horn sounds, horn blast effects and tire trails as pure cosmetics. A Garage screen.
- **Where:** `catalog.json` / `GameCatalog`; perks applied when coins/XP are awarded.

## 7. Monetization: rewarded ads, capped interstitials, IAP
- **Rewarded (opt-in):** double the coins from a run; one free mystery box per day (odds
  shown).
- **Interstitials:** at most one every 3–4 runs and no more often than every ~3 min, never in
  the first session or tutorial, and never right after a personal best. Removed by Remove
  Ads or the Supporter Pack.
- **IAP (StoreKit 2):** Remove Ads / Supporter Pack (one-time, includes an exclusive car),
  coin packs, and cosmetic bundles. Restore Purchases. A `.storekit` config for testing.
- No "continue after crash" for now. It can be added later as a remote-config experiment.
- **Where:** `StoreService` and `AdService` (AdMob) protocols with mocks; App Tracking
  Transparency prompt, privacy manifest, and the UMP consent form for the EU.
- **Tone pass:** pedestrians and dogs *startle and dodge* instead of dying. Booze becomes a
  goofy debuff (e.g., "Sleepy" / energy-drink jitters) that reuses the screen effect.
  Rename the `dontDrinkAndDrive` alert.

## 8. Game feel: visual effects and haptics
- **Visual:** screen shake and a brief freeze on hits, particle bursts, speed lines and road
  blur as speed rises, and a zone-transition sweep.
- **Haptics:** distinct CoreHaptics patterns for hits, near-misses, combo level-ups,
  pickups and zone changes.
- Game-over screen: score breakdown, "X to beat your best", mission/level progress. Split
  `GameOverView` into components.

## 9. Social: achievements, friends leaderboard, review prompt
- 20–30 Game Center achievements.
- A friends-only leaderboard view for all-time and daily scores.
- `requestReview` after a personal best or level-up, at most a few times a year, never after
  a loss.

## 10. Production: Firebase + CI
- **Firebase Analytics:** run start/end, cause of death, zone reached, combo peak, tutorial
  funnel, store/ad events.
- **Remote Config:** overrides the bundled JSON for difficulty, missions, prices and the
  interstitial cap.
- **Crashlytics**, plus Xcode Cloud or GitHub Actions running tests and pushing TestFlight
  builds.

## 11. Art direction upgrade
- **Style guide first:** one pixel resolution, a limited shared palette, outline and shading
  rules, and an animation frame budget.
- **Now (packs):** zone road tiles, the base car set, obstacles, and an FX sheet, all
  recolored to the shared palette.
- **Later (commission):** hero cars, the app icon, App Store screenshots and key art.
- New "startled/dodge" animations for pedestrians and dogs.

---

## Order of work
1. **Dev mode and test hooks** (D0–D4), inserted before the rest.
2. **Groundwork and feel:** ~~#0~~ → #8 visual effects/haptics → #1 combos → #5
   onboarding/controls.
3. **Content and tone:** #11 style guide + packs → #4 zones → tone pass (#7) → #6 catalog.
4. **Retention:** #2 missions/levels → #3 daily run → #9 achievements/friends/review.
5. **Launch readiness:** #10 Firebase + CI → #7 ads/IAP → **extend dev mode to TestFlight
   builds** (it is debug-only for now) → TestFlight beta → App Store.
