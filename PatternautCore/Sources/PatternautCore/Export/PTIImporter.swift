import Foundation

/// Parses Polyend `.pti` bytes back into an ``Instrument``: the counterpart of
/// ``PTIExporter``, reading the same 16-byte header, 376-byte parameter block
/// and raw PCM tail.
///
/// The channel count is not stored anywhere in the file. The device writes
/// stereo as two de-interleaved blocks and records the frame count, so the
/// audio length against that count is what says whether a file is stereo.
///
/// Re-writing a file the device wrote reproduces it except in three places this
/// model does not carry: the device leaves the old file extension after the
/// name's terminator, its reserved bytes at offset 56 differ, and it pads the
/// end with `FF FF` rather than zeros. `tracker-lib` writes those the way we do,
/// so what we produce is what other tools produce.
public enum PTIImporter {
    public enum PTIError: Error, Equatable, LocalizedError {
        case tooSmall(Int)
        case invalidSignature(String)

        public var errorDescription: String? {
            switch self {
            case .tooSmall(let size):
                return "That .pti is only \(size) bytes, too short to hold an instrument."
            case .invalidSignature(let found):
                return "That file is not a Polyend instrument (its signature is \"\(found)\")."
            }
        }
    }

    public static func parse(_ data: Data) throws -> Instrument {
        let b = [UInt8](data)
        let headerSize = 16
        guard b.count >= headerSize + PTIExporter.mainFieldsSize else { throw PTIError.tooSmall(b.count) }

        let idFile = String(decoding: b[0..<2], as: UTF8.self)
        guard idFile == "TI" else { throw PTIError.invalidSignature(idFile) }

        let header = Instrument.Header(
            idFile: idFile,
            type: Int(u16(b, 2)),
            fwVersion: Array(b[4..<8]),
            fileStructureVersion: Array(b[8..<12]),
            size: Int(u16(b, 12))
        )

        var o = headerSize
        let isActive = b[o] != 0
        o += 4

        // Sample bank slot
        let sampleType = Instrument.SampleType(rawValue: Int(b[o])) ?? .waveFile
        o += 1
        let nameBytes = Array(b[o..<(o + 32)])
        let filename = String(decoding: nameBytes.prefix { $0 != 0 }, as: UTF8.self)
        o += 32
        o += 3 + 4 // padding + reserved
        let frames = Int(u32(b, o)); o += 4
        o += 2 + 2 // window size + padding
        let wavetableWindowCount = Int(u32(b, o)); o += 4

        o += 4 // reserved

        let playmode = Instrument.PlayMode(rawValue: Int(b[o])) ?? .oneShot
        o += 2

        let startPoint = Int(u16(b, o)); o += 2
        let loopPoint1 = Int(u16(b, o)); o += 2
        let loopPoint2 = Int(u16(b, o)); o += 2
        let endPoint = Int(u16(b, o)); o += 2
        o += 2
        let wavetableCurrentWindow = Int(u32(b, o)); o += 4

        var envelopes: [(Instrument.Envelope, Bool, Bool)] = []
        for _ in 0..<6 {
            let amount = f32(b, o); o += 4
            let delay = Int(u16(b, o)); o += 2
            let attack = Int(u16(b, o)); o += 2
            o += 2 // hold, always zero
            let decay = Int(u16(b, o)); o += 2
            let sustain = f32(b, o); o += 4
            let release = Int(u16(b, o)); o += 2
            let isLFO = b[o] != 0; o += 1
            let enabled = b[o] != 0; o += 1
            envelopes.append((Instrument.Envelope(amount: amount, delay: delay, attack: attack,
                                                  decay: decay, sustain: sustain, release: release),
                              isLFO, enabled))
        }

        var lfos: [Instrument.LFO] = []
        for _ in 0..<6 {
            let shape = Instrument.LFOShape(rawValue: Int(b[o])) ?? .revSaw; o += 1
            let speed = Instrument.LFOSpeed(rawValue: Int(b[o])) ?? .s4; o += 1
            o += 2
            let amount = f32(b, o); o += 4
            lfos.append(Instrument.LFO(shape: shape, speed: speed, amount: amount))
        }

        let automations = (0..<6).map { index in
            Instrument.Automation(enabled: envelopes[index].2, isLFO: envelopes[index].1,
                                  envelope: envelopes[index].0, lfo: lfos[index])
        }

        let cutoff = f32(b, o); o += 4
        // Stored scaled; see the writer.
        let resonance = Float(Double(f32(b, o)) / 4.3); o += 4

        let filterType = Instrument.FilterType(rawValue: Int(b[o])) ?? .lowPass; o += 1
        let filterEnabled = b[o] != 0; o += 1
        let tune = Int(Int8(bitPattern: b[o])); o += 1
        let finetune = Int(Int8(bitPattern: b[o])); o += 1

        let volume = Float(b[o]) / 50; o += 4
        let panning = Float(i16(b, o) - 50) / 50; o += 2
        let delaySend = Float(b[o]) / 100; o += 2

        var slices: [Int] = []
        for _ in 0..<48 { slices.append(Int(u16(b, o))); o += 2 }
        let numSlices = Int(b[o]); o += 1
        let selectedSlice = Int(b[o]); o += 1

        let grainLength = Int(u16(b, o)); o += 2
        let grainPosition = Int(u16(b, o)); o += 2
        let grainShape = Instrument.GranularShape(rawValue: Int(b[o])) ?? .square; o += 1
        let grainType = Instrument.GranularType(rawValue: Int(b[o])) ?? .forward; o += 1

        let reverbSend = Float(b[o]) / 100; o += 1
        let overdrive = Float(b[o]) / 100; o += 1
        let bitdepth = Int(b[o]); o += 1
        o += 1 + 2 // reserved + final padding, ending the parameter block

        // The audio sits straight after the parameter block, and the block's
        // padding to 376 bytes trails at the very end of the file rather than
        // before the audio. This mirrors the writer, which mirrors tracker-lib.
        let audioStart = min(o, b.count)
        let trailingPadding = max(0, PTIExporter.mainFieldsSize - (audioStart - headerSize))
        let audioEnd = max(audioStart, b.count - trailingPadding)
        let audio = Array(b[audioStart..<audioEnd])
        let channels = frames > 0 && audio.count >= frames * 4 ? 2 : 1
        let pcm = channels == 2 ? interleave(audio, frames: frames) : Data(audio)

        return Instrument(
            header: header,
            isActive: isActive,
            sample: Instrument.SampleSlot(type: sampleType, filename: filename, length: frames,
                                          wavetableWindowCount: wavetableWindowCount, channels: channels),
            playmode: playmode,
            startPoint: startPoint, loopPoint1: loopPoint1, loopPoint2: loopPoint2, endPoint: endPoint,
            wavetableCurrentWindow: wavetableCurrentWindow,
            automations: automations,
            cutoff: cutoff, resonance: resonance, filterType: filterType, filterEnabled: filterEnabled,
            tune: tune, finetune: finetune, volume: volume, panning: panning,
            delaySend: delaySend, reverbSend: reverbSend,
            slices: slices, numSlices: numSlices, selectedSlice: selectedSlice,
            granular: Instrument.Granular(grainLength: grainLength, currentPosition: grainPosition,
                                          shape: grainShape, type: grainType),
            overdrive: overdrive, bitdepth: bitdepth,
            pcm: pcm
        )
    }

    /// Puts the device's two de-interleaved channel blocks back into the
    /// interleaved layout a WAV uses.
    private static func interleave(_ audio: [UInt8], frames: Int) -> Data {
        var out = [UInt8]()
        out.reserveCapacity(frames * 4)
        let rightStart = frames * 2
        for frame in 0..<frames {
            let l = frame * 2
            let r = rightStart + frame * 2
            guard r + 1 < audio.count else { break }
            out.append(audio[l]); out.append(audio[l + 1])
            out.append(audio[r]); out.append(audio[r + 1])
        }
        return Data(out)
    }

    // MARK: - Byte helpers

    private static func u16(_ b: [UInt8], _ o: Int) -> UInt16 {
        UInt16(b[o]) | (UInt16(b[o + 1]) << 8)
    }
    private static func i16(_ b: [UInt8], _ o: Int) -> Int {
        Int(Int16(bitPattern: u16(b, o)))
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | (UInt32(b[o + 1]) << 8) | (UInt32(b[o + 2]) << 16) | (UInt32(b[o + 3]) << 24)
    }
    private static func f32(_ b: [UInt8], _ o: Int) -> Float {
        Float(bitPattern: u32(b, o))
    }
}
