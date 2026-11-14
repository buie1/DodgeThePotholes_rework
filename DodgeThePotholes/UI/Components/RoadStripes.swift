import SwiftUI

/// Decorative vertical road stripes behind the main menu.
struct RoadStripes: View {

    var body: some View {
        GeometryReader { geo in
            let stripeCount = 5
            let w = geo.size.width / CGFloat(stripeCount + 1)
            HStack(spacing: w - 3) {
                ForEach(0..<stripeCount, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}
