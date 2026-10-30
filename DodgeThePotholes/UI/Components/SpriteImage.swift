import SwiftUI

/// A legacy pixel-art sprite from the asset catalog, scaled without smoothing.
struct SpriteImage: View {
    let image: SpriteCatalog.Image

    init(_ image: SpriteCatalog.Image) {
        self.image = image
    }

    var body: some View {
        Image(image.rawValue)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
}

#Preview {
    HStack {
        SpriteImage(.wheel).frame(width: 40)
        SpriteImage(.dollar).frame(width: 40)
        SpriteImage(.star).frame(width: 40)
    }
    .padding()
    .background(.black)
}
