import AVFoundation
import Foundation

final class BellModalAudioEngine: BellAudioPlaying {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var dsp: OpaquePointer?
    private(set) var isReady = false

    deinit {
        stop()
    }

    @discardableResult
    func prepare() -> Bool {
        if isReady, engine.isRunning { return true }
        stop()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ) else { return false }

        let modalModes = BellModalProfile.smallBrassHandbell.map {
            BellModalMode(
                frequency_hz: Float($0.frequency),
                decay_seconds: Float($0.decay),
                gain: Float($0.gain)
            )
        }
        let createdDSP = modalModes.withUnsafeBufferPointer { buffer in
            BellModalDSPCreate(
                format.sampleRate,
                UInt32(format.channelCount),
                buffer.baseAddress,
                UInt32(buffer.count)
            )
        }
        guard let createdDSP else { return false }

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let leftData = buffers.first?.mData else { return noErr }
            let left = leftData.assumingMemoryBound(to: Float.self)
            let right = buffers.count > 1
                ? buffers[1].mData?.assumingMemoryBound(to: Float.self)
                : nil
            BellModalDSPRender(createdDSP, left, right, UInt32(frameCount))
            return noErr
        }

        dsp = createdDSP
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()

        do {
            try engine.start()
            isReady = true
            return true
        } catch {
            stop()
            return false
        }
    }

    @discardableResult
    func enqueue(_ impact: BellImpactEvent) -> Bool {
        guard isReady, engine.isRunning, let dsp else { return false }
        let payload = BellModalImpactMapping.payload(for: impact)
        let cImpact = BellDSPImpact(
            timestamp: payload.timestamp,
            strength: Float(payload.strength),
            normal_speed: Float(payload.normalSpeed),
            contact_x: Float(payload.contactDirection.x),
            contact_y: Float(payload.contactDirection.y),
            contact_z: Float(payload.contactDirection.z),
            tangential_speed: Float(payload.tangentialSpeed)
        )
        return BellModalDSPEnqueueImpact(dsp, cImpact)
    }

    @discardableResult
    func play(impact: BellImpactEvent, config: BellConfig) -> Bool {
        enqueue(impact)
    }

    func stop() {
        isReady = false
        engine.stop()
        engine.reset()
        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }
        sourceNode = nil
        if let dsp {
            BellModalDSPDestroy(dsp)
        }
        dsp = nil
    }

    @discardableResult
    func rebuild() -> Bool {
        stop()
        return prepare()
    }
}
