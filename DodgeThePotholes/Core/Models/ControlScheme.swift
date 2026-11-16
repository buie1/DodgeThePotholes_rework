import Foundation

/// How the player steers.
enum ControlScheme: String, CaseIterable {
    /// Lean the phone left and right. A finger dragging sideways still overrides it.
    case tilt
    /// Drag a finger sideways. The accelerometer stays off.
    case drag
}

/// Where the player is with the first-run tutorial.
enum TutorialStatus: String {
    /// Never played it. Plays on the first game, unless they already have finished runs.
    case new
    /// Asked to replay it from Settings; plays on the next game.
    case requested
    /// Finished or skipped.
    case done
}
