import Foundation

struct BellPresentationConfiguration {
    let overallProjectedScale: CGFloat
    let tiltTowardViewer: Float
    let backgroundWhite: CGFloat
    let usesHDR: Bool

    static let referenceTuned = BellPresentationConfiguration(
        overallProjectedScale: 0.90,
        tiltTowardViewer: -0.27,
        backgroundWhite: 1.0,
        usesHDR: false
    )

    var openingFacingComponent: Float {
        -sin(tiltTowardViewer)
    }

    func cameraDistance(from baseDistance: CGFloat) -> CGFloat {
        baseDistance / overallProjectedScale
    }

    func projectedDimension(_ dimension: CGFloat, atBaseDistance baseDistance: CGFloat) -> CGFloat {
        dimension * baseDistance / cameraDistance(from: baseDistance)
    }

    func brassRoughness(base: CGFloat, row: Int) -> CGFloat {
        let scrambled = (row &* 73 &+ 19) % 101
        let centeredNoise = CGFloat(scrambled) / 100 - 0.5
        return min(max(base + centeredNoise * 0.026, 0), 1)
    }
}
