import Foundation

/// The cars and shop items, loaded from `Resources/Config/catalog.json`.
///
/// Adding a car or shop item is a JSON entry plus its art; no code change.
/// View models take a `GameCatalog` value, so a remotely fetched copy can
/// replace `bundled` later.
struct GameCatalog: Decodable, Equatable {
    /// Every car, in display order. The first one with no `unlockKey` is free.
    let cars: [CarSkin]
    /// Everything for sale, in display order.
    let shopItems: [ShopItem]

    private enum CodingKeys: String, CodingKey {
        case cars
        case shopItems = "shop"
    }

    /// The car a new player drives, and the fallback for an unknown saved car.
    var defaultCar: CarSkin {
        cars.first { $0.unlockKey == nil } ?? cars[0]
    }

    /// The car with `id`, if the catalog has one.
    func car(id: String) -> CarSkin? {
        cars.first { $0.id == id }
    }

    /// The shop item with `id`, if the catalog has one.
    func shopItem(id: String) -> ShopItem? {
        shopItems.first { $0.id == id }
    }

    // MARK: - Loading

    enum LoadError: Error {
        case missingResource(String)
    }

    /// The catalog shipped in the app bundle.
    static let bundled: GameCatalog = {
        do {
            return try load()
        } catch {
            preconditionFailure("Bundled catalog.json failed to load: \(error)")
        }
    }()

    /// Loads and decodes `catalog.json`.
    /// - Parameter bundle: The bundle containing the JSON; defaults to the app bundle.
    static func load(in bundle: Bundle = .main) throws -> GameCatalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw LoadError.missingResource("catalog.json")
        }
        return try JSONDecoder().decode(GameCatalog.self, from: Data(contentsOf: url))
    }
}
