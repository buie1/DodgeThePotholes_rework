import SwiftUI

extension Font {
    /// The legacy pixel font (Press Start 2P), bundled and registered via `UIAppFonts`.
    static func pixel(_ size: CGFloat) -> Font {
        .custom("Press Start 2P", size: size)
    }
}
