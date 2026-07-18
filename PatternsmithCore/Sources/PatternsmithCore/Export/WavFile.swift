import Foundation

/// Minimal 16-bit PCM WAV helpers: read format/frames, extract the `data`
/// chunk, and build a canonical WAV from raw PCM. Enough to move sample data in
/// and out of `.pti` instruments (which store raw PCM, not a WAV container).
public enum WavFile {
    public struct Info: Sendable, Equatable {
        public let channels: Int
        public let sampleRate: Int
        public let bitsPerSample: Int
        public let frames: Int
    }

    public enum WavError: Error, Equatable {
        case notRIFF
        case noFormatChunk
        case noDataChunk
    }

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
        return Info(channels: channels, sampleRate: sampleRate, bitsPerSample: bits, frames: dataChunk.size / bytesPerFrame)
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
