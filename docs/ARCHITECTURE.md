# System Architecture Document

## 1. High-Level Architecture
┌────────────────────────────────────────────────────────┐
│                      SwiftUI UI                        │
│   (MainMenuView, GameView, GameOverView, SettingsView)  │
└──────────────────────────┬─────────────────────────────┘
│ @Observable
┌──────────────────────────▼─────────────────────────────┐
│                    GameViewModel                       │
└──────────────┬──────────────────────────┬──────────────┘
│                          │
┌──────────────▼──────────┐    ┌──────────▼──────────────┐
│       GameEngine        │    │    Services / Managers  │
│ (Collision, Spawning,   │    │  (AudioService,         │
│  Physics, World Loop)   │    │   ScoreService,         │
└─────────────────────────┘    │   HapticService)        │
└─────────────────────────┘

## 2. Component Breakdown
1. **GameEngine**: Runs the core loop, manages entity positions (Player, Potholes, Items), handles bounding-box collisions, and updates game delta time.
2. **GameViewModel**: Connects the engine output to SwiftUI views, exposes dynamic high scores, and manages sound/haptic triggers.
3. **Services**: Protocol-driven implementations for local data persistence and haptics.
