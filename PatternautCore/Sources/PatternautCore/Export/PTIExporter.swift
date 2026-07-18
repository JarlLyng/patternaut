import Foundation

/// Serializes an ``Instrument`` to Polyend `.pti` bytes: 16-byte header, a
/// 376-byte parameter block, then raw PCM (de-interleaved for stereo). Ported
/// from `tracker-lib` `Instrument.write` and verified byte-for-byte against it.
public enum PTIExporter {
    static let mainFieldsSize = 376

    public static func export(_ ins: Instrument) -> Data {
        var out = [UInt8]()
        out.reserveCapacity(16 + mainFieldsSize + ins.pcm.count)

        writeHeader(&out, ins.header)

        var mf = [UInt8]()
        writeMainFields(&mf, ins)
        out.append(contentsOf: mf)

        out.append(contentsOf: rawAudio(ins))

        // Trailing padding so total == 16 + 376 + audio (matches tracker-lib,
        // whose audio starts at the main-fields-end offset).
        let pad = mainFieldsSize - mf.count
        if pad > 0 { out.append(contentsOf: repeatElement(0, count: pad)) }

        return Data(out)
    }

    // MARK: - Header

    private static func writeHeader(_ b: inout [UInt8], _ h: Instrument.Header) {
        let id = Array(h.idFile.utf8.prefix(2))
        b.append(id.first ?? 0)
        b.append(id.count > 1 ? id[1] : 0)
        appendU16LE(&b, h.type)
        for i in 0..<4 { b.append(i < h.fwVersion.count ? h.fwVersion[i] : 0) }
        for i in 0..<4 { b.append(i < h.fileStructureVersion.count ? h.fileStructureVersion[i] : 0) }
        appendU16LE(&b, h.size)
        appendZeros(&b, 2)
    }

    // MARK: - Main fields

    private static func writeMainFields(_ b: inout [UInt8], _ ins: Instrument) {
        b.append(ins.isActive ? 1 : 0)
        appendZeros(&b, 3)

        writeSampleBankSlot(&b, ins.sample)

        appendZeros(&b, 4) // reserved

        b.append(UInt8(ins.playmode.rawValue))
        appendZeros(&b, 1)

        appendU16LE(&b, ins.startPoint)
        appendU16LE(&b, ins.loopPoint1)
        appendU16LE(&b, ins.loopPoint2)
        appendU16LE(&b, ins.endPoint)
        appendZeros(&b, 2)

        appendU32LE(&b, ins.wavetableCurrentWindow)

        for auto in ins.automations { writeEnvelope(&b, auto) }
        for auto in ins.automations { writeLFO(&b, auto.lfo) }

        appendF32LE(&b, ins.cutoff)
        appendF32LE(&b, Float(Double(ins.resonance) * 4.3))

        b.append(UInt8(ins.filterType.rawValue))
        b.append(ins.filterEnabled ? 1 : 0)
        appendI8(&b, ins.tune)
        appendI8(&b, ins.finetune)

        b.append(UInt8(truncatingIfNeeded: Int(ins.volume * 50)))
        appendZeros(&b, 3)

        appendI16LE(&b, Int(ins.panning * 50 + 50))

        b.append(UInt8(truncatingIfNeeded: Int((ins.delaySend * 100).rounded())))
        appendZeros(&b, 1)

        for i in 0..<48 { appendU16LE(&b, i < ins.slices.count ? ins.slices[i] : 0) }

        b.append(UInt8(truncatingIfNeeded: ins.numSlices))
        b.append(UInt8(truncatingIfNeeded: ins.selectedSlice))

        appendU16LE(&b, ins.granular.grainLength)
        appendU16LE(&b, ins.granular.currentPosition)
        b.append(UInt8(ins.granular.shape.rawValue))
        b.append(UInt8(ins.granular.type.rawValue))

        b.append(UInt8(truncatingIfNeeded: Int((ins.reverbSend * 100).rounded())))
        b.append(UInt8(truncatingIfNeeded: Int((ins.overdrive * 100).rounded())))
        b.append(UInt8(truncatingIfNeeded: ins.bitdepth))
        appendZeros(&b, 1) // reserved

        appendZeros(&b, 2) // final padding
    }

    private static func writeSampleBankSlot(_ b: inout [UInt8], _ s: Instrument.SampleSlot) {
        b.append(UInt8(s.type.rawValue))
        let name = Array((s.filename.isEmpty ? "untitled" : s.filename).utf8)
        for i in 0..<32 { b.append(i < name.count ? name[i] : 0) }
        appendZeros(&b, 3)
        b.append(contentsOf: [0x00, 0xA0, 0x26, 0x80]) // reserved (from hardware)
        appendU32LE(&b, s.length)
        appendU16LE(&b, 2048) // window size, hardcoded by tracker-lib
        appendZeros(&b, 2)
        appendU32LE(&b, s.wavetableWindowCount)
    }

    private static func writeEnvelope(_ b: inout [UInt8], _ auto: Instrument.Automation) {
        appendF32LE(&b, auto.envelope.amount)
        appendU16LE(&b, auto.envelope.delay)
        appendU16LE(&b, auto.envelope.attack)
        appendU16LE(&b, 0) // hold (always 0)
        appendU16LE(&b, auto.envelope.decay)
        appendF32LE(&b, auto.envelope.sustain)
        appendU16LE(&b, auto.envelope.release)
        b.append(auto.isLFO ? 1 : 0)
        b.append(auto.enabled ? 1 : 0)
    }

    private static func writeLFO(_ b: inout [UInt8], _ lfo: Instrument.LFO) {
        b.append(UInt8(lfo.shape.rawValue))
        b.append(UInt8(lfo.speed.rawValue))
        appendZeros(&b, 2)
        appendF32LE(&b, lfo.amount)
    }

    // MARK: - Audio

    private static func rawAudio(_ ins: Instrument) -> [UInt8] {
        let pcm = [UInt8](ins.pcm)
        guard ins.sample.channels == 2 else { return pcm }
        let frames = ins.sample.length
        var left = [UInt8](); left.reserveCapacity(frames * 2)
        var right = [UInt8](); right.reserveCapacity(frames * 2)
        for i in 0..<frames {
            let base = i * 4
            if base + 3 < pcm.count {
                left.append(pcm[base]); left.append(pcm[base + 1])
                right.append(pcm[base + 2]); right.append(pcm[base + 3])
            } else {
                left.append(0); left.append(0); right.append(0); right.append(0)
            }
        }
        return left + right
    }

    // MARK: - Byte helpers

    private static func appendU16LE(_ b: inout [UInt8], _ value: Int) {
        let v = UInt16(truncatingIfNeeded: value)
        b.append(UInt8(v & 0xFF)); b.append(UInt8((v >> 8) & 0xFF))
    }
    private static func appendI16LE(_ b: inout [UInt8], _ value: Int) {
        let v = UInt16(bitPattern: Int16(truncatingIfNeeded: value))
        b.append(UInt8(v & 0xFF)); b.append(UInt8((v >> 8) & 0xFF))
    }
    private static func appendU32LE(_ b: inout [UInt8], _ value: Int) {
        let v = UInt32(truncatingIfNeeded: value)
        b.append(UInt8(v & 0xFF)); b.append(UInt8((v >> 8) & 0xFF))
        b.append(UInt8((v >> 16) & 0xFF)); b.append(UInt8((v >> 24) & 0xFF))
    }
    private static func appendF32LE(_ b: inout [UInt8], _ value: Float) {
        let bits = value.bitPattern
        b.append(UInt8(bits & 0xFF)); b.append(UInt8((bits >> 8) & 0xFF))
        b.append(UInt8((bits >> 16) & 0xFF)); b.append(UInt8((bits >> 24) & 0xFF))
    }
    private static func appendI8(_ b: inout [UInt8], _ value: Int) {
        b.append(UInt8(bitPattern: Int8(truncatingIfNeeded: value)))
    }
    private static func appendZeros(_ b: inout [UInt8], _ count: Int) {
        b.append(contentsOf: repeatElement(0, count: count))
    }
}
