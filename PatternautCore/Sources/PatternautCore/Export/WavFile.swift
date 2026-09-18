import Foundation

/// Minimal WAV helpers: read format/frames, extract the `data` chunk, convert
/// common formats to the 16-bit PCM the Tracker expects, and build a canonical
/// WAV from raw PCM. Enough to move sample data in and out of `.pti`
/// instruments (which store raw PCM, not a WAV container).
public enum WavFile {
    public struct Info: Sendable, Equatable {
        public let channels: Int
        public let sampleRate: Int
        public let bitsPerSample: Int
        public let frames: Int
        /// True for IEEE float samples (32- or 64-bit) rather than integer PCM.
        public let isFloat: Bool

        public init(channels: Int, sampleRate: Int, bitsPerSample: Int, frames: Int, isFloat: Bool = false) {
            self.channels = channels
            self.sampleRate = sampleRate
            self.bitsPerSample = bitsPerSample
            self.frames = frames
            self.isFloat = isFloat
        }
    }

    public enum WavError: Error, Equatable {
        case notRIFF
        case noFormatChunk
        case noDataChunk
        /// A bit depth or encoding this reader cannot convert to 16-bit PCM.
        case unsupportedFormat(bitsPerSample: Int, isFloat: Bool)
    }

    /// The sample rate the Tracker plays `.pti` audio back at. Anything else has
    /// to be resampled or it will play at the wrong pitch.
    public static let trackerSampleRate = 44100

    /// Reads channel/rate/frame info without copying the audio.
    public static func info(_ data: Data) throws -> Info {
        let b = [UInt8](data)
        try requireRIFF(b)
        guard let fmt = findChunk(b, "fmt ") else { throw WavError.noFormatChunk }
        let channels = Int(readU16LE(b, fmt.body + 2))
        let sampleRate = Int(readU32LE(b, fmt.body + 4))
        let bits = Int(readU16LE(b, fmt.body + 14))
        guard let dataChunk = findChunk(b, "data") else { throw WavError.noDataChunk }
        let bytesPerFrame = max(1, channels * (bits / 8))
        return Info(channels: channels, sampleRate: sampleRate, bitsPerSample: bits,
                    frames: dataChunk.size / bytesPerFrame, isFloat: isFloat(b, fmt: fmt))
    }

    /// Converts any supported WAV to the interleaved 16-bit PCM a `.pti` holds,
    /// resampling to ``trackerSampleRate`` when needed.
    ///
    /// Most drum samples in the wild are 24-bit or 32-bit float, so accepting
    /// only 16-bit would reject the majority of a user's library. Resampling is
    /// linear interpolation: fine for one-shots and loops, not a mastering-grade
    /// sample-rate converter.
    public static func pcm16(_ data: Data) throws -> (pcm: Data, info: Info) {
        let source = try info(data)
        var samples = try samples16(data, info: source)
        var frames = source.channels > 0 ? samples.count / source.channels : 0

        if source.sampleRate != trackerSampleRate, source.sampleRate > 0, frames > 1 {
            samples = resample(samples, channels: source.channels,
                               from: source.sampleRate, to: trackerSampleRate)
            frames = source.channels > 0 ? samples.count / source.channels : 0
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(samples.count * 2)
        for sample in samples { appendU16LE(&bytes, UInt16(bitPattern: sample)) }
        let converted = Info(channels: source.channels, sampleRate: trackerSampleRate,
                             bitsPerSample: 16, frames: frames, isFloat: false)
        return (Data(bytes), converted)
    }

    // MARK: - Conversion

    /// Decodes the data chunk into interleaved 16-bit samples.
    private static func samples16(_ data: Data, info source: Info) throws -> [Int16] {
        let pcm = [UInt8](try pcmData(data))
        switch (source.bitsPerSample, source.isFloat) {
        case (16, false):
            return stride(from: 0, to: pcm.count - 1, by: 2).map {
                Int16(bitPattern: readU16LE(pcm, $0))
            }
        case (8, false):
            // 8-bit WAV is unsigned, centred on 128.
            return pcm.map { Int16((Int($0) - 128) << 8) }
        case (24, false):
            return stride(from: 0, to: pcm.count - 2, by: 3).map { offset in
                let value = Int(pcm[offset]) | (Int(pcm[offset + 1]) << 8) | (Int(pcm[offset + 2]) << 16)
                let signed = value & 0x80_0000 != 0 ? value - 0x100_0000 : value
                return Int16(clamping: signed >> 8)
            }
        case (32, false):
            return stride(from: 0, to: pcm.count - 3, by: 4).map { offset in
                Int16(clamping: Int(Int32(bitPattern: readU32LE(pcm, offset))) >> 16)
            }
        case (32, true):
            return stride(from: 0, to: pcm.count - 3, by: 4).map { offset in
                clampFloat(Double(Float(bitPattern: readU32LE(pcm, offset))))
            }
        case (64, true):
            return stride(from: 0, to: pcm.count - 7, by: 8).map { offset in
                let bits = UInt64(readU32LE(pcm, offset)) | (UInt64(readU32LE(pcm, offset + 4)) << 32)
                return clampFloat(Double(bitPattern: bits))
            }
        default:
            throw WavError.unsupportedFormat(bitsPerSample: source.bitsPerSample, isFloat: source.isFloat)
        }
    }

    /// Float samples are nominally -1...1 but can overshoot, so clamp.
    private static func clampFloat(_ value: Double) -> Int16 {
        guard value.isFinite else { return 0 }
        return Int16(clamping: Int((Swift.min(Swift.max(value, -1), 1) * 32767).rounded()))
    }

    /// Linear-interpolation resampling, keeping channels interleaved.
    private static func resample(_ samples: [Int16], channels: Int, from: Int, to: Int) -> [Int16] {
        guard channels > 0, from > 0, to > 0, from != to else { return samples }
        let sourceFrames = samples.count / channels
        guard sourceFrames > 1 else { return samples }
        let ratio = Double(from) / Double(to)
        let targetFrames = Swift.max(1, Int((Double(sourceFrames) / ratio).rounded(.down)))
        var result = [Int16]()
        result.reserveCapacity(targetFrames * channels)
        for frame in 0..<targetFrames {
            let position = Double(frame) * ratio
            let index = Int(position)
            let fraction = position - Double(index)
            let next = Swift.min(index + 1, sourceFrames - 1)
            for channel in 0..<channels {
                let a = Double(samples[index * channels + channel])
                let b = Double(samples[next * channels + channel])
                result.append(Int16(clamping: Int((a + (b - a) * fraction).rounded())))
            }
        }
        return result
    }

    /// True when the `fmt` chunk declares IEEE float samples, including inside
    /// the extensible format's sub-format GUID.
    private static func isFloat(_ b: [UInt8], fmt: Chunk) -> Bool {
        let format = readU16LE(b, fmt.body)
        if format == 3 { return true }
        // WAVE_FORMAT_EXTENSIBLE carries the real format in the sub-format GUID.
        if format == 0xFFFE, fmt.size >= 26 { return readU16LE(b, fmt.body + 24) == 3 }
        return false
    }

    /// Returns the raw bytes of the `data` chunk (interleaved PCM).
    public static func pcmData(_ data: Data) throws -> Data {
        let b = [UInt8](data)
        try requireRIFF(b)
        guard let dataChunk = findChunk(b, "data") else { throw WavError.noDataChunk }
        return Data(b[dataChunk.body..<dataChunk.body + dataChunk.size])
    }

    /// Builds a canonical 16-bit PCM WAV from interleaved PCM bytes.
    public static func make(pcm: Data, channels: Int, sampleRate: Int = 44100) -> Data {
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        var b = [UInt8]()
        b.append(contentsOf: Array("RIFF".utf8))
        appendU32LE(&b, UInt32(36 + pcm.count))
        b.append(contentsOf: Array("WAVE".utf8))
        b.append(contentsOf: Array("fmt ".utf8))
        appendU32LE(&b, 16)
        appendU16LE(&b, 1) // PCM
        appendU16LE(&b, UInt16(channels))
        appendU32LE(&b, UInt32(sampleRate))
        appendU32LE(&b, UInt32(byteRate))
        appendU16LE(&b, UInt16(blockAlign))
        appendU16LE(&b, UInt16(bitsPerSample))
        b.append(contentsOf: Array("data".utf8))
        appendU32LE(&b, UInt32(pcm.count))
        b.append(contentsOf: pcm)
        return Data(b)
    }

    // MARK: - Private

    private struct Chunk { let body: Int; let size: Int }

    private static func requireRIFF(_ b: [UInt8]) throws {
        guard b.count >= 12,
              String(decoding: b[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: b[8..<12], as: UTF8.self) == "WAVE" else { throw WavError.notRIFF }
    }

    private static func findChunk(_ b: [UInt8], _ id: String) -> Chunk? {
        var offset = 12
        while offset + 8 <= b.count {
            let chunkId = String(decoding: b[offset..<offset + 4], as: UTF8.self)
            let size = Int(readU32LE(b, offset + 4))
            let body = offset + 8
            if chunkId == id { return Chunk(body: body, size: min(size, b.count - body)) }
            offset = body + size + (size % 2) // chunks are word-aligned
        }
        return nil
    }

    private static func readU16LE(_ b: [UInt8], _ o: Int) -> UInt16 { UInt16(b[o]) | (UInt16(b[o + 1]) << 8) }
    private static func readU32LE(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | (UInt32(b[o + 1]) << 8) | (UInt32(b[o + 2]) << 16) | (UInt32(b[o + 3]) << 24)
    }
    private static func appendU16LE(_ b: inout [UInt8], _ v: UInt16) { b.append(UInt8(v & 0xFF)); b.append(UInt8(v >> 8)) }
    private static func appendU32LE(_ b: inout [UInt8], _ v: UInt32) {
        b.append(UInt8(v & 0xFF)); b.append(UInt8((v >> 8) & 0xFF)); b.append(UInt8((v >> 16) & 0xFF)); b.append(UInt8((v >> 24) & 0xFF))
    }
}
