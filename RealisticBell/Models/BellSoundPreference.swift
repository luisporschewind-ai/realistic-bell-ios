import Foundation

struct BellSoundPreference: Equatable {
    var isEnabled = false

    var shouldPlaySound: Bool {
        isEnabled
    }

    var shouldPrepareAudio: Bool {
        isEnabled
    }
}
