import AVFoundation
import Foundation

enum BellSampleBufferConverter {
    enum ConversionError: Error {
        case cannotCreateConverter
        case cannotCreateBuffer
        case conversionFailed
    }

    static func convert(
        _ source: AVAudioPCMBuffer,
        to targetFormat: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(
            from: source.format,
            to: targetFormat
        ) else { throw ConversionError.cannotCreateConverter }

        let ratio = targetFormat.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(
            ceil(Double(source.frameLength) * ratio) + 32
        )
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity
        ) else { throw ConversionError.cannotCreateBuffer }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return source
        }
        guard conversionError == nil,
              status == .haveData || status == .endOfStream else {
            throw conversionError ?? ConversionError.conversionFailed
        }
        return output
    }
}

final class BellSampleAudioEngine: BellAudioPlaying {
    private struct Voice {
        let player: AVAudioPlayerNode
        let pitch: AVAudioUnitTimePitch
    }

    private let engine = AVAudioEngine()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48_000,
        channels: 2,
        interleaved: false
    )!
    private var voices: [Voice] = []
    private var buffers: [AVAudioPCMBuffer] = []
    private var nextVoiceIndex = 0
    private var isReady = false

    init() {
        loadSamples()
        configureEngine()
    }

    @discardableResult
    func prepare() -> Bool {
        guard !buffers.isEmpty, !voices.isEmpty else { return false }
        if engine.isRunning {
            isReady = true
            return true
        }
        do {
            engine.prepare()
            try engine.start()
            isReady = true
            return true
        } catch {
            isReady = false
            return false
        }
    }

    @discardableResult
    func play(impact: BellImpactEvent, config: BellConfig) -> Bool {
        guard isReady, engine.isRunning,
              !buffers.isEmpty, !voices.isEmpty else { return false }

        let voice = voices[nextVoiceIndex % voices.count]
        nextVoiceIndex += 1
        let buffer = buffers[nextVoiceIndex % buffers.count]
        let volume = Float(min(
            max((0.18 + impact.strength * 0.82) * config.volumeGain, 0),
            1
        ))
        let centsRange = Float(config.pitchRandomness * 1_200)
        voice.pitch.pitch = Float.random(in: -centsRange...centsRange)
        voice.player.volume = volume
        if !voice.player.isPlaying { voice.player.play() }
        voice.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        return true
    }

    func stop() {
        isReady = false
        voices.forEach { $0.player.stop() }
        engine.stop()
        engine.reset()
        nextVoiceIndex = 0
    }

    func update(contact: BellContactState, profile: BellContactSoundProfile) {}

    private func loadSamples() {
        let names = (1...5).map { String(format: "bell_hit_%02d", $0) }
        buffers = names.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
                return nil
            }
            do {
                let file = try AVAudioFile(forReading: url)
                guard let source = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                ) else { return nil }
                try file.read(into: source)
                return try BellSampleBufferConverter.convert(source, to: playbackFormat)
            } catch {
                return nil
            }
        }
    }

    private func configureEngine() {
        guard !buffers.isEmpty else { return }
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            engine.attach(player)
            engine.attach(pitch)
            engine.connect(player, to: pitch, format: playbackFormat)
            engine.connect(pitch, to: engine.mainMixerNode, format: playbackFormat)
            voices.append(Voice(player: player, pitch: pitch))
        }
        engine.prepare()
    }
}
