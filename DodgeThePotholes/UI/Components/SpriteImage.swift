import SwiftUI

/// A legacy pixel-art sprite from the asset catalog, scaled without smoothing.
struct SpriteImage: View {
    let name: String

    init(_ image: SpriteCatalog.Image) {
        self.name = image.rawValue
    }

    /// A sprite by asset name, e.g. a `CarSkin.imageName` from the catalog.
    init(named name: String) {
        self.name = name
    }

    var body: some View {
        Image(name)
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
