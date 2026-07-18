import Foundation

/// Classic tracker keyboard-to-pitch mapping (Renoise/Impulse-style): the
/// `z`-row is the lower octave, the `q`-row the octave above, black keys on the
/// rows between. Returns a semitone offset from the base octave's C.
public enum NoteKeyMap {
    private static let offsets: [Character: Int] = [
        // Lower octave (z row)
        "z": 0, "s": 1, "x": 2, "d": 3, "c": 4, "v": 5, "g": 6, "b": 7,
        "h": 8, "n": 9, "j": 10, "m": 11, ",": 12, "l": 13, ".": 14, "/": 16,
        // Upper octave (q row)
        "q": 12, "2": 13, "w": 14, "3": 15, "e": 16, "r": 17, "5": 18, "t": 19,
        "6": 20, "y": 21, "7": 22, "u": 23, "i": 24, "9": 25, "o": 26, "p": 28,
    ]

    /// Semitone offset from the base octave's C for `key`, or `nil` if the key
    /// is not a note key.
    public static func semitoneOffset(for key: Character) -> Int? {
        offsets[Character(key.lowercased())]
    }

    /// The MIDI note for `key` at `baseOctave`, or `nil`.
    ///
    /// Uses the MIDI convention where C4 = 60, so octave `o` starts at
    /// `(o + 1) * 12`. Out-of-range results are clamped to `0...127`.
    public static func note(for key: Character, baseOctave: Int) -> Note? {
        guard let offset = semitoneOffset(for: key) else { return nil }
        let midi = (baseOctave + 1) * 12 + offset
        return Note(rawValue: min(max(midi, 0), 127))
    }
}
