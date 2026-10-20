import Foundation

/// A sample instrument decoded for listening: its audio as floats, plus the
/// instrument settings the preview honours.
public struct PlayableSample: Sendable {
    /// The note that plays a sample at its own pitch. The Tracker shows raw
    /// note 60 as C5, and its manual's percussion walkthrough sets "C5, the root
    /// note for the sample". Patternaut names the same note C4.
    public static let rootNote = 60
    /// The rate `.pti` audio is stored at.
    public static let sampleRate = 44_100.0

    public let left: [Float]
    /// The same frames as `left` for a mono sample.
    public let right: [Float]
    /// Instrument volume as a gain: `1` plays the sample as recorded.
    public var gain: Float
    /// Instrument panning, `-1` left to `1` right.
    public var panning: Float
    /// Instrument Tune and Finetune together, in semitones.
    public var tune: Double
    /// The part of the sample that plays, from the instrument's start and end points.
    public var startFrame: Int
    public var endFrame: Int
    /// How long a note-off takes to die away, from the volume envelope's release.
    public var release: Double

    public var frameCount: Int { left.count }

    public init(left: [Float], right: [Float]? = nil, gain: Float = 1, panning: Float = 0,
                tune: Double = 0, release: Double = 0.1) {
        self.left = left
        self.right = right ?? left
        self.gain = gain
        self.panning = panning
        self.tune = tune
        self.startFrame = 0
        self.endFrame = left.count
        self.release = release
    }

    /// Decodes an instrument's 16-bit PCM and reads the settings that shape
    /// how it sounds.
    public init(instrument: Instrument) {
        let channels = max(1, instrument.sample.channels)
        let frames = instrument.pcm.count / (2 * channels)
        var left = [Float](repeating: 0, count: frames)
        var right = channels == 2 ? [Float](repeating: 0, count: frames) : []
        instrument.pcm.withUnsafeBytes { raw in
            for frame in 0..<frames {
                let offset = frame * channels * 2
                left[frame] = Float(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: Int16.self))) / 32_768
                if channels == 2 {
                    right[frame] = Float(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: offset + 2, as: Int16.self))) / 32_768
                }
            }
        }
        self.init(left: left, right: channels == 2 ? right : nil)

        // The `.pti` keeps volume as 0...2, where 1 is the sample as it is.
        gain = max(0, instrument.volume)
        panning = min(max(instrument.panning, -1), 1)
        tune = Double(instrument.tune) + Double(instrument.finetune) / 100
        // Start and end points are fractions of the sample, stored as 0...65535.
        let start = Int(Double(instrument.startPoint) / 65_535 * Double(frames))
        let end = Int(Double(instrument.endPoint) / 65_535 * Double(frames))
        startFrame = min(max(start, 0), max(frames - 1, 0))
        endFrame = min(max(end, startFrame + 1), frames)
        if let envelope = instrument.automations.first, envelope.enabled {
            release = min(max(Double(envelope.envelope.release) / 1_000, 0.005), 4)
        } else {
            release = 0.005
        }
    }
}
