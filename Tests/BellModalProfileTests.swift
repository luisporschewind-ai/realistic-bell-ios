import Foundation

@main
struct BellModalProfileTests {
    static func main() {
        let modes = BellModalProfile.smallBrassHandbell
        precondition((12...30).contains(modes.count))
        precondition(modes.allSatisfy { $0.frequency > 0 && $0.frequency < 24_000 })
        precondition(modes.allSatisfy { $0.decay > 0 && $0.gain > 0 })

        for index in 1..<modes.count {
            precondition(modes[index].frequency > modes[index - 1].frequency)
        }
        precondition(modes.first!.decay > modes.last!.decay * 5)

        let ratios = (1..<modes.count).map {
            modes[$0].frequency / modes[$0 - 1].frequency
        }
        precondition(
            ratios.max()! - ratios.min()! > 0.08,
            "A handbell profile must be non-harmonic rather than equally spaced"
        )
        print("BellModalProfileTests passed")
    }
}
