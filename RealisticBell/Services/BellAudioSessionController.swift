import AVFoundation
import Foundation

@MainActor
final class BellAudioSessionController {
    var onRecoveryNeeded: (() -> Void)?

    private let session: AVAudioSession
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(
        session: AVAudioSession = .sharedInstance(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.session = session
        self.notificationCenter = notificationCenter
        registerNotifications()
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }

    @discardableResult
    func activate() -> Bool {
        do {
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    func deactivate() {
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func registerNotifications() {
        let names: [Notification.Name] = [
            AVAudioSession.interruptionNotification,
            AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereResetNotification,
            .AVAudioEngineConfigurationChange
        ]
        observers = names.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if notification.name == AVAudioSession.interruptionNotification,
                       let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey]
                            as? UInt,
                       AVAudioSession.InterruptionType(rawValue: rawType) == .began {
                        return
                    }
                    self.onRecoveryNeeded?()
                }
            }
        }
    }
}
