import Foundation

struct BellSoundPreference: Equatable {
    var isEnabled = true

    var shouldPlaySound: Bool {
        isEnabled
    }

    var shouldPrepareAudio: Bool {
        isEnabled
    }
}
