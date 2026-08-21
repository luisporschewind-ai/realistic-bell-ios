enum BellAudioBackend: Equatable {
    case stopped
    case modal
    case sampleFallback
}

enum BellAudioRoutingPolicy {
    static func preparedBackend(modalReady: Bool, sampleReady: Bool) -> BellAudioBackend {
        if modalReady { return .modal }
        if sampleReady { return .sampleFallback }
        return .stopped
    }

    static func eventBackend(
        active: BellAudioBackend,
        modalAccepted: Bool,
        sampleReady: Bool
    ) -> BellAudioBackend {
        if active == .modal, modalAccepted { return .modal }
        return sampleReady ? .sampleFallback : .stopped
    }
}
