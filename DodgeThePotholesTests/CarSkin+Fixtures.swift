@testable import DodgeThePotholes

/// The three bundled cars by their legacy names, for readable assertions.
extension CarSkin {
    static var blue:  CarSkin { GameCatalog.bundled.car(id: "car1")! }
    static var red:   CarSkin { GameCatalog.bundled.car(id: "car2")! }
    static var green: CarSkin { GameCatalog.bundled.car(id: "car3")! }
}
