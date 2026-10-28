# Product Requirement Document (PRD): DodgeThePotholes

## 1. Executive Summary
DodgeThePotholes is a casual arcade-style mobile game where players navigate an vehicle/avatar along a dynamic roadway, dodging incoming obstacles (potholes, debris) while collecting power-ups and chasing high scores.

## 2. Core Player Experience & Mechanics
- **Player Control**: Drag/touch gestures or tilt controls to move horizontally.
- **Obstacle Spawning**: Variable speed and frequency scaling with player score/time.
- **Power-ups & Collectibles**: Shield, speed boost, point multipliers.
- **Scoring System**: Continuous distance/time-based scoring plus bonus item pick-ups.
- **Game States**: Main Menu, Active Gameplay, Pause Menu, Game Over / Leaderboards.

## 3. Key Non-Functional Requirements
- 60 FPS / 120 FPS target performance.
- Full Haptic feedback integrated with collisions and power-ups.
- Offline support with local high score storage using SwiftData.
- Modular engine structure allowing future multiplayer/social features.
