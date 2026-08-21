struct BellModalDefinition: Equatable {
    let frequency: Double
    let decay: Double
    let gain: Double
}

enum BellModalProfile {
    static let smallBrassHandbell: [BellModalDefinition] = [
        .init(frequency: 680, decay: 1.80, gain: 0.38),
        .init(frequency: 942, decay: 1.55, gain: 0.26),
        .init(frequency: 1_247, decay: 1.30, gain: 0.22),
        .init(frequency: 1_683, decay: 1.05, gain: 0.18),
        .init(frequency: 2_104, decay: 0.90, gain: 0.14),
        .init(frequency: 2_731, decay: 0.72, gain: 0.11),
        .init(frequency: 3_408, decay: 0.58, gain: 0.09),
        .init(frequency: 4_267, decay: 0.46, gain: 0.07),
        .init(frequency: 5_119, decay: 0.36, gain: 0.055),
        .init(frequency: 6_381, decay: 0.28, gain: 0.042),
        .init(frequency: 7_744, decay: 0.22, gain: 0.032),
        .init(frequency: 9_216, decay: 0.17, gain: 0.024)
    ]
}
