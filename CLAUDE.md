# Claude CLI Development Guidelines - DodgeThePotholes

## Project Overview
DodgeThePotholes is a modernized iOS game rewritten from a legacy codebase. The app focuses on smooth game mechanics, modern SwiftUI UI, clean architecture, and maintainability.

## Technology Stack
- **Language**: Swift 5.10+ / Swift 6
- **UI Framework**: SwiftUI (iOS 17+)
- **State Management**: `@Observable` macro (Swift Observation framework)
- **Game Engine**: SpriteKit embedded within SwiftUI (`SpriteView`) or custom SwiftUI timeline animation loops depending on complexity.
- **Persistence**: SwiftData / UserDefaults for high scores and user settings.
- **Audio/Haptics**: CoreHaptics & AVFoundation.

## Architecture & Design Patterns
- **MVVM / Unidirectional Data Flow**: Views observe ViewModels; ViewModels drive Game Engines.
- **Dependency Injection**: Use protocols for audio, score managers, and storage services.
- **Theme**: Clean modern aesthetic with customizable UI tokens defined in `UI/Theme`.

## Development Commands & Workflows
- **Build**: `xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 15' build`
- **Test**: `xcodebuild -scheme DodgeThePotholes -destination 'platform=iOS Simulator,name=iPhone 15' test`

## Code Style & Rules
- Keep Views declarative, modular, and under 150 lines.
- Extract reusable components into `UI/Components`.
- Do not use legacy `@StateObject` / `@ObservedObject` unless forced by backward compatibility; use modern `@Observable`.
- Use explicit Swift concurrency (`async/await`, `@MainActor`) over `DispatchQueue.main.async`.
- Document public APIs using standard Swift doc comments (`///`).
