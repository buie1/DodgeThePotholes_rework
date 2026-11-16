import Foundation

/// How the player steers.
enum ControlScheme: String, CaseIterable {
    /// Lean the phone left and right. A finger dragging sideways still overrides it.
    case tilt
    /// Drag a finger sideways. The accelerometer stays off.
    case drag
}
