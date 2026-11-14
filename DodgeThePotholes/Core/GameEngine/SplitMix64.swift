/// Small, fast, seedable random generator (SplitMix64).
///
/// The same seed always yields the same sequence on every device, which makes
/// seeded runs (and engine tests) reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    /// - Parameter seed: Starting state; equal seeds produce equal sequences.
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
