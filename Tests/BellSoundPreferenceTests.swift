@main
struct BellSoundPreferenceTests {
    static func main() {
        precondition(BellSoundPreference().isEnabled == false, "Sound must be off by default")
        precondition(BellSoundPreference(isEnabled: false).shouldPlaySound == false, "Disabled sound must not play")
        precondition(BellSoundPreference(isEnabled: true).shouldPlaySound == true, "Enabled sound must play")
        precondition(BellSoundPreference(isEnabled: false).shouldPrepareAudio == false, "Disabled sound must not prepare audio")
        precondition(BellSoundPreference(isEnabled: true).shouldPrepareAudio == true, "Enabled sound should prepare audio")
        print("BellSoundPreferenceTests passed")
    }
}
