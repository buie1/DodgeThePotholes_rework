import Foundation

/// A coin or cone layout loaded from a bundled `Resources/Patterns/*.json` file.
///
/// Tile values: `0` = empty, `1` = coin / cone, `2` = barricade (cone patterns only).
/// Row 0 is the top row as written in the JSON.
struct TilePattern: Decodable, Equatable {
    let tiles: [[Int]]
    let numCols: Int
    let numRows: Int

    /// Bundled pattern file names (without extension).
    enum Name: String, CaseIterable {
        case money1 = "money_pattern1"
        case money2 = "money_pattern2"
        case money3 = "money_pattern3"
        case money4 = "money_pattern4"
        case cone1  = "cone_pattern1"
        case cone2  = "cone_pattern2"
        case cone3  = "cone_pattern3"

        static let money: [Name] = [.money1, .money2, .money3, .money4]
        static let cone:  [Name] = [.cone1, .cone2, .cone3]
    }

    enum LoadError: Error {
        case missingResource(String)
    }

    /// Loads and decodes a bundled pattern.
    /// - Parameter bundle: The bundle containing the JSON; defaults to the app bundle.
    static func load(_ name: Name, in bundle: Bundle = .main) throws -> TilePattern {
        guard let url = bundle.url(forResource: name.rawValue, withExtension: "json") else {
            throw LoadError.missingResource(name.rawValue)
        }
        return try JSONDecoder().decode(TilePattern.self, from: Data(contentsOf: url))
    }

    /// Converts the JSON rows into an `Array2D` indexed bottom-up (row 0 = bottom),
    /// matching the legacy `currRow = NumRows - row - 1` convention.
    var grid: Array2D<Int> {
        var grid = Array2D<Int>(columns: numCols, rows: numRows)
        for (row, values) in tiles.enumerated() {
            for (col, value) in values.enumerated() where value != 0 {
                grid[col, numRows - row - 1] = value
            }
        }
        return grid
    }
}
