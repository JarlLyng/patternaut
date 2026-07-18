import Foundation
import Testing
@testable import PatternsmithCore

@Suite("PTI instrument export")
struct PTIExporterTests {
    // MARK: Fixtures

    struct Vectors: Codable { let cases: [Case] }
    struct Case: Codable {
        let name: String
        let header: HeaderSpec
        let isActive: Bool
        let sample: SampleSpec
        let playmode: Int
        let startPoint, loopPoint1, loopPoint2, endPoint: Int
        let wavetableCurrentWindow: Int
        let automations: [AutoSpec]
        let cutoff, resonance: Float
        let filterType: Int
        let filterEnabled: Bool
        let tune, finetune: Int
        let volume, panning, delaySend, reverbSend: Float
        let slices: [Int]
        let numSlices, selectedSlice: Int
        let granular: GranularSpec
        let overdrive: Float
        let bitdepth: Int
        let wavBase64: String
        let expectedBase64: String
    }
    struct HeaderSpec: Codable { let idFile: String; let type: Int; let fwVersion: [UInt8]; let fileStructureVersion: [UInt8]; let size: Int }
    struct SampleSpec: Codable { let type: Int; let filename: String; let length: Int; let wavetableWindowCount: Int; let channels: Int }
    struct AutoSpec: Codable { let enabled: Bool; let isLFO: Bool; let envelope: EnvSpec; let lfo: LFOSpec }
    struct EnvSpec: Codable { let amount: Float; let delay: Int; let attack: Int; let decay: Int; let sustain: Float; let release: Int }
    struct LFOSpec: Codable { let shape: Int; let speed: Int; let amount: Float }
    struct GranularSpec: Codable { let grainLength: Int; let currentPosition: Int; let shape: Int; let type: Int }

    static func loadVectors() throws -> Vectors {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/pti_vectors.json")
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
    }

    func makeInstrument(_ c: Case) throws -> Instrument {
        let wav = Data(base64Encoded: c.wavBase64)!
        let pcm = try WavFile.pcmData(wav)
        let automations = c.automations.map { a in
            Instrument.Automation(
                enabled: a.enabled, isLFO: a.isLFO,
                envelope: Instrument.Envelope(amount: a.envelope.amount, delay: a.envelope.delay, attack: a.envelope.attack, decay: a.envelope.decay, sustain: a.envelope.sustain, release: a.envelope.release),
                lfo: Instrument.LFO(shape: Instrument.LFOShape(rawValue: a.lfo.shape)!, speed: Instrument.LFOSpeed(rawValue: a.lfo.speed)!, amount: a.lfo.amount)
            )
        }
        return Instrument(
            header: Instrument.Header(idFile: c.header.idFile, type: c.header.type, fwVersion: c.header.fwVersion, fileStructureVersion: c.header.fileStructureVersion, size: c.header.size),
            isActive: c.isActive,
            sample: Instrument.SampleSlot(type: Instrument.SampleType(rawValue: c.sample.type)!, filename: c.sample.filename, length: c.sample.length, wavetableWindowCount: c.sample.wavetableWindowCount, channels: c.sample.channels),
            playmode: Instrument.PlayMode(rawValue: c.playmode)!,
            startPoint: c.startPoint, loopPoint1: c.loopPoint1, loopPoint2: c.loopPoint2, endPoint: c.endPoint,
            wavetableCurrentWindow: c.wavetableCurrentWindow,
            automations: automations,
            cutoff: c.cutoff, resonance: c.resonance, filterType: Instrument.FilterType(rawValue: c.filterType)!, filterEnabled: c.filterEnabled,
            tune: c.tune, finetune: c.finetune, volume: c.volume, panning: c.panning, delaySend: c.delaySend, reverbSend: c.reverbSend,
            slices: c.slices, numSlices: c.numSlices, selectedSlice: c.selectedSlice,
            granular: Instrument.Granular(grainLength: c.granular.grainLength, currentPosition: c.granular.currentPosition, shape: Instrument.GranularShape(rawValue: c.granular.shape)!, type: Instrument.GranularType(rawValue: c.granular.type)!),
            overdrive: c.overdrive, bitdepth: c.bitdepth,
            pcm: pcm
        )
    }

    @Test("PTI export matches tracker-lib byte-for-byte")
    func matchesOracle() throws {
        let vectors = try Self.loadVectors()
        #expect(vectors.cases.count == 3)
        for c in vectors.cases {
            let data = PTIExporter.export(try makeInstrument(c))
            let expected = Data(base64Encoded: c.expectedBase64)!
            #expect(data.count == expected.count, "\(c.name): size \(data.count) vs \(expected.count)")
            #expect(data == expected, "\(c.name): bytes differ from tracker-lib")
        }
    }

    @Test("Instrument.new matches createInstrument defaults")
    func defaultsMatchCreateInstrument() throws {
        let vectors = try Self.loadVectors()
        let mono = vectors.cases[0] // 'default mono'
        let wav = Data(base64Encoded: mono.wavBase64)!
        let instrument = try Instrument.new(wav: wav)
        #expect(PTIExporter.export(instrument) == Data(base64Encoded: mono.expectedBase64)!)
    }

    @Test("WAV helper reads mono and stereo frame counts")
    func wavInfo() throws {
        let vectors = try Self.loadVectors()
        let stereo = vectors.cases[2]
        let info = try WavFile.info(Data(base64Encoded: stereo.wavBase64)!)
        #expect(info.channels == 2)
        #expect(info.frames == stereo.sample.length)
    }
}
