import AVFoundation

@main
struct BellSampleBufferConverterTests {
    static func main() throws {
        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        )!
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        )!
        let source = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 441)!
        source.frameLength = 441
        for frame in 0..<Int(source.frameLength) {
            source.floatChannelData![0][frame] = Float(frame) / 441
        }

        let converted = try BellSampleBufferConverter.convert(
            source,
            to: targetFormat
        )
        precondition(converted.format == targetFormat)
        precondition(converted.format.channelCount == 2)
        precondition(converted.format.sampleRate == 48_000)
        precondition((478...482).contains(Int(converted.frameLength)))
        precondition(converted.floatChannelData![0][200].isFinite)
        precondition(converted.floatChannelData![1][200].isFinite)
        print("BellSampleBufferConverterTests passed")
    }
}
