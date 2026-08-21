import Foundation

@main
struct BellContactSoundProfileTests {
    static func main() {
        let profile = BellContactSoundProfile.smallBrassHandbell

        precondition(profile.loadReference.isFinite && profile.loadReference > 0)
        precondition(profile.speedReference.isFinite && profile.speedReference > 0)
        precondition(profile.surfaceSamplesPerMeter.isFinite && profile.surfaceSamplesPerMeter > 0)
        precondition(
            (1.0...2.5).contains(profile.excitationGain),
            "Contact excitation must reach an audible level without approaching impact loudness"
        )
        precondition((0.005...0.010).contains(profile.attackSeconds))
        precondition((0.030...0.050).contains(profile.releaseSeconds))
        precondition(profile.timeoutSeconds == 0.080)
        precondition((0..<12).contains(profile.firstExcitedModeIndex))
        print("BellContactSoundProfileTests passed")
    }
}
