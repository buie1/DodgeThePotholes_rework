import Foundation

/// A row-major 2-D grid backed by a flat array.
/// Used for coin and cone pattern data loaded from JSON.
struct Array2D<T> {
    let columns: Int
    let rows: Int
    private var storage: [T?]

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.storage = Array(repeating: nil, count: columns * rows)
    }

    subscript(column: Int, row: Int) -> T? {
        get { storage[row * columns + column] }
        set { storage[row * columns + column] = newValue }
    }
}
