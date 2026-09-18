import Foundation
import Testing
@testable import PatternautCore

@Suite("WAV conversion")
struct WavConversionTests {
    /// Builds a WAV with an arbitrary format chunk, so the reader can be tested
    /// against the shapes real sample libraries ship in.
    func wav(bits: Int, isFloat: Bool, channels: Int = 1, rate: Int = 44100, body: [UInt8]) -> Data {
        var b = [UInt8]()
        func u16(_ v: Int) { b.append(UInt8(v & 0xFF)); b.append(UInt8((v >> 8) & 0xFF)) }
        func u32(_ v: Int) { u16(v & 0xFFFF); u16((v >> 16) & 0xFFFF) }
        b.append(contentsOf: Array("RIFF".utf8)); u32(36 + body.count)
        b.append(contentsOf: Array("WAVE".utf8))
        b.append(contentsOf: Array("fmt ".utf8)); u32(16)
        u16(isFloat ? 3 : 1)
        u16(channels); u32(rate)
        u32(rate * channels * bits / 8); u16(channels * bits / 8); u16(bits)
        b.append(contentsOf: Array("data".utf8)); u32(body.count)
        b.append(contentsOf: body)
        return Data(b)
    }

    func samples(_ pcm: Data) -> [Int16] {
        let b = [UInt8](pcm)
        return stride(from: 0, to: b.count - 1, by: 2).map { Int16(bitPattern: UInt16(b[$0]) | (UInt16(b[$0 + 1]) << 8)) }
    }

    @Test("16-bit PCM passes through untouched")
    func passthrough() throws {
        let body: [UInt8] = [0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80] // 0, max, min
        let (pcm, info) = try WavFile.pcm16(wav(bits: 16, isFloat: false, body: body))
        #expect(samples(pcm) == [0, 32767, -32768])
        #expect(info.bitsPerSample == 16)
        #expect(info.frames == 3)
    }

    @Test("24-bit converts by keeping the top 16 bits, sign intact")
    func twentyFourBit() throws {
        // 0, +full scale, -full scale, little-endian 3-byte samples.
        let body: [UInt8] = [0x00, 0x00, 0x00, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x80]
        let (pcm, _) = try WavFile.pcm16(wav(bits: 24, isFloat: false, body: body))
        let out = samples(pcm)
        #expect(out.count == 3)
        #expect(out[0] == 0)
        #expect(out[1] == 32767)
        #expect(out[2] == -32768)
    }

    @Test("32-bit float scales and clamps overshoot")
    func floatSamples() throws {
        var body = [UInt8]()
        for value in [Float(0), Float(0.5), Float(-1), Float(1.8)] {
            let bits = value.bitPattern
            body.append(contentsOf: [UInt8(bits & 0xFF), UInt8((bits >> 8) & 0xFF),
                                     UInt8((bits >> 16) & 0xFF), UInt8((bits >> 24) & 0xFF)])
        }
        let (pcm, _) = try WavFile.pcm16(wav(bits: 32, isFloat: true, body: body))
        let out = samples(pcm)
        #expect(out[0] == 0)
        #expect(out[1] == 16384) // 0.5 * 32767, rounded
        #expect(out[2] == -32767)
        #expect(out[3] == 32767) // clamped, not wrapped
    }

    @Test("8-bit unsigned is re-centred on zero")
    func eightBit() throws {
        let (pcm, _) = try WavFile.pcm16(wav(bits: 8, isFloat: false, body: [128, 255, 0]))
        let out = samples(pcm)
        #expect(out[0] == 0)
        #expect(out[1] > 32000)
        #expect(out[2] == -32768)
    }

    @Test("A 48 kHz sample is resampled to the rate the Tracker plays at")
    func resampling() throws {
        // One second of 48 kHz mono becomes about one second of 44.1 kHz.
        let frames = 48000
        var body = [UInt8]()
        for index in 0..<frames {
            let value = Int16(truncatingIfNeeded: index)
            let bits = UInt16(bitPattern: value)
            body.append(UInt8(bits & 0xFF)); body.append(UInt8(bits >> 8))
        }
        let (pcm, info) = try WavFile.pcm16(wav(bits: 16, isFloat: false, rate: 48000, body: body))
        #expect(info.sampleRate == 44100)
        #expect(abs(info.frames - 44100) <= 1)
        #expect(samples(pcm).count == info.frames)
    }

    @Test("Stereo frames stay interleaved through a rate change")
    func stereoResampling() throws {
        var body = [UInt8]()
        for index in 0..<1000 {
            for channel in 0..<2 {
                let bits = UInt16(bitPattern: Int16(channel == 0 ? 1000 : -1000))
                _ = index
                body.append(UInt8(bits & 0xFF)); body.append(UInt8(bits >> 8))
            }
        }
        let (pcm, info) = try WavFile.pcm16(wav(bits: 16, isFloat: false, channels: 2, rate: 22050, body: body))
        #expect(info.channels == 2)
        #expect(samples(pcm).count == info.frames * 2)
        // Left stays positive and right stays negative: channels did not smear.
        let out = samples(pcm)
        #expect(stride(from: 0, to: out.count, by: 2).allSatisfy { out[$0] > 0 })
        #expect(stride(from: 1, to: out.count, by: 2).allSatisfy { out[$0] < 0 })
    }

    @Test("An unsupported bit depth reports what it found")
    func unsupported() {
        let data = wav(bits: 12, isFloat: false, body: [0, 0, 0, 0])
        #expect(throws: WavFile.WavError.unsupportedFormat(bitsPerSample: 12, isFloat: false)) {
            try WavFile.pcm16(data)
        }
    }

    @Test("A 24-bit WAV becomes a valid .pti instrument")
    func instrumentFrom24Bit() throws {
        var body = [UInt8]()
        for index in 0..<300 { body.append(contentsOf: [0, UInt8(index % 256), 0x10]) }
        let instrument = try Instrument.new(wav: wav(bits: 24, isFloat: false, body: body), filename: "dusty")
        #expect(instrument.sample.channels == 1)
        #expect(instrument.sample.length == 300)
        #expect(instrument.pcm.count == 600) // 16-bit now
        #expect(!instrument.data().isEmpty)
    }
}
