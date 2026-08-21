import Foundation

@main
struct BellPresentationConfigurationTests {
    static func main() {
        let presentation = BellPresentationConfiguration.referenceTuned

        let displayedSize = presentation.projectedDimension(100, atBaseDistance: 4.0)
        precondition(abs(displayedSize - 90) < 0.001, "The whole bell must appear 10 percent smaller")
        precondition(presentation.openingFacingComponent >= 0.25, "The fixed pose must expose the hollow opening")
        precondition(presentation.backgroundWhite >= 0.98, "The reference stage must remain white")
        precondition(!presentation.usesHDR, "HDR tone mapping must not turn the white stage gray")

        let roughness = (0..<1024).map { presentation.brassRoughness(base: 0.46, row: $0) }
        let variation = roughness.max()! - roughness.min()!
        precondition(variation > 0.005, "Brass needs visible fine-grain variation")
        precondition(variation <= 0.03, "Brass variation must not create broad horizontal bands")

        print("BellPresentationConfigurationTests passed")
    }
}
