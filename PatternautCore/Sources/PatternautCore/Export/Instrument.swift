import Foundation

/// A Polyend `.pti` instrument: sample reference, playback settings, envelopes,
/// LFOs, filter, slices, granular params, and the raw 16-bit PCM sample.
///
/// Field ranges and defaults mirror `tracker-lib` `createInstrument`. Values are
/// stored in their logical form (e.g. `volume` 0…2, `panning` -1…1); the writer
/// applies the on-disk scaling.
public struct Instrument: Sendable, Equatable {
    public var header: Header
    public var isActive: Bool
    public var sample: SampleSlot
    public var playmode: PlayMode
    public var startPoint: Int
    public var loopPoint1: Int
    public var loopPoint2: Int
    public var endPoint: Int
    public var wavetableCurrentWindow: Int
    public var automations: [Automation]
    public var cutoff: Float
    public var resonance: Float
    public var filterType: FilterType
    public var filterEnabled: Bool
    public var tune: Int
    public var finetune: Int
    public var volume: Float
    public var panning: Float
    public var delaySend: Float
    public var reverbSend: Float
    public var slices: [Int]
    public var numSlices: Int
    public var selectedSlice: Int
    public var granular: Granular
    public var overdrive: Float
    public var bitdepth: Int
    /// Interleaved 16-bit PCM (the WAV `data` chunk).
    public var pcm: Data

    // MARK: Nested types

    public struct Header: Sendable, Equatable {
        public var idFile: String
        public var type: Int
        public var fwVersion: [UInt8]
        public var fileStructureVersion: [UInt8]
        public var size: Int
        public init(idFile: String = "TI", type: Int = 1, fwVersion: [UInt8] = [1, 9, 1, 1],
                    fileStructureVersion: [UInt8] = [9, 9, 9, 9], size: Int = 372) {
            self.idFile = idFile; self.type = type; self.fwVersion = fwVersion
            self.fileStructureVersion = fileStructureVersion; self.size = size
        }
    }

    public struct SampleSlot: Sendable, Equatable {
        public var type: SampleType
        public var filename: String
        public var length: Int
        public var wavetableWindowCount: Int
        public var channels: Int
        public init(type: SampleType = .waveFile, filename: String = "untitled", length: Int = 0,
                    wavetableWindowCount: Int = 0, channels: Int = 1) {
            self.type = type; self.filename = filename; self.length = length
            self.wavetableWindowCount = wavetableWindowCount; self.channels = channels
        }
    }

    public struct Automation: Sendable, Equatable {
        public var enabled: Bool
        public var isLFO: Bool
        public var envelope: Envelope
        public var lfo: LFO
        public init(enabled: Bool, isLFO: Bool, envelope: Envelope, lfo: LFO) {
            self.enabled = enabled; self.isLFO = isLFO; self.envelope = envelope; self.lfo = lfo
        }
    }

    public struct Envelope: Sendable, Equatable {
        public var amount: Float
        public var delay: Int
        public var attack: Int
        public var decay: Int
        public var sustain: Float
        public var release: Int
        public init(amount: Float = 1, delay: Int = 0, attack: Int = 0, decay: Int = 0, sustain: Float = 1, release: Int = 1000) {
            self.amount = amount; self.delay = delay; self.attack = attack
            self.decay = decay; self.sustain = sustain; self.release = release
        }
    }

    public struct LFO: Sendable, Equatable {
        public var shape: LFOShape
        public var speed: LFOSpeed
        public var amount: Float
        public init(shape: LFOShape = .triangle, speed: LFOSpeed = .s4, amount: Float = 0) {
            self.shape = shape; self.speed = speed; self.amount = amount
        }
    }

    public struct Granular: Sendable, Equatable {
        public var grainLength: Int
        public var currentPosition: Int
        public var shape: GranularShape
        public var type: GranularType
        public init(grainLength: Int = 4410, currentPosition: Int = 0, shape: GranularShape = .triangle, type: GranularType = .forward) {
            self.grainLength = grainLength; self.currentPosition = currentPosition; self.shape = shape; self.type = type
        }
    }

    public enum SampleType: Int, Sendable { case waveFile = 0, wavetable = 1 }
    public enum PlayMode: Int, Sendable {
        case oneShot = 0, forwardLoop, backwardLoop, pingpongLoop, slice, beatSlice, wavetable, granular
    }
    public enum FilterType: Int, Sendable { case lowPass = 0, highPass, bandPass }
    public enum LFOShape: Int, Sendable { case revSaw = 0, saw, triangle, square, random }
    /// LFO rate, as note divisions. Values from `tracker-lib` `LFO_SPEED`.
    public enum LFOSpeed: Int, Sendable, CaseIterable {
        case s128 = 0, s96, s64, s48, s32, s24, s16, s12, s8, s6, s4, s3, s2
        case s3over2, s1, s3over4, s1over2, s3over8, s1over3, s1over4, s3over16
        case s1over6, s1over8, s1over12, s1over16, s1over24, s1over32, s1over48, s1over64
    }
    public enum GranularShape: Int, Sendable { case square = 0, triangle, gauss }
    public enum GranularType: Int, Sendable { case forward = 0, backward, pingPong }

    // MARK: Construction

    /// Creates an instrument from a WAV, matching `createInstrument` defaults
    /// (one-shot, full range, envelope 0 enabled).
    ///
    /// The audio is converted to the 16-bit, 44.1 kHz PCM a `.pti` stores, so
    /// 24-bit and float sources (most of a modern sample library) load as they
    /// are.
    public static func new(wav: Data, filename: String = "untitled") throws -> Instrument {
        let (pcm, info) = try WavFile.pcm16(wav)
        let automations = (0..<6).map { i in
            Automation(enabled: i == 0, isLFO: false, envelope: Envelope(), lfo: LFO())
        }
        return Instrument(
            header: Header(),
            isActive: true,
            sample: SampleSlot(filename: filename, length: info.frames, channels: info.channels),
            playmode: .oneShot,
            startPoint: 0, loopPoint1: 0, loopPoint2: 65534, endPoint: 65535,
            wavetableCurrentWindow: 0,
            automations: automations,
            cutoff: 1.0, resonance: 0.0, filterType: .lowPass, filterEnabled: false,
            tune: 0, finetune: 0, volume: 1.0, panning: 0.0, delaySend: 0.0, reverbSend: 0.0,
            slices: Array(repeating: 0, count: 48), numSlices: 0, selectedSlice: 0,
            granular: Granular(), overdrive: 0.0, bitdepth: 16,
            pcm: pcm
        )
    }

    /// Serializes to `.pti` bytes.
    public func data() -> Data { PTIExporter.export(self) }
}
