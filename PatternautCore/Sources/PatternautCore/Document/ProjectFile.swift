import Foundation

/// Everything a saved Patternaut document holds: the patterns being worked on,
/// the samples loaded alongside them, and the settings that shaped them.
///
/// This is the app's own format, not the device's. It exists so work survives
/// quitting, which exporting to a card does not provide: an exported project is
/// what the Tracker needs, and drops the seed, the key and the original audio.
public struct ProjectFile: Codable, Equatable, Sendable {
    /// Bumped when the shape changes in a way older builds cannot read.
    public static let currentVersion = 1

    public var version: Int
    public var projectName: String
    public var device: DeviceModel
    public var tempo: Double
    public var baseOctave: Int
    public var key: MusicalKey
    public var patterns: [Pattern]
    public var instruments: [Sample]

    /// A loaded sample, stored as a canonical 16-bit WAV so the document stands
    /// on its own: moving the file does not lose the audio.
    public struct Sample: Codable, Equatable, Sendable {
        public var name: String
        public var wav: Data

        public init(name: String, wav: Data) {
            self.name = name
            self.wav = wav
        }
    }

    public init(
        version: Int = ProjectFile.currentVersion,
        projectName: String = "Patternaut",
        device: DeviceModel = .trackerPlus,
        tempo: Double = 130,
        baseOctave: Int = 4,
        key: MusicalKey = MusicalKey(),
        patterns: [Pattern] = [],
        instruments: [Sample] = []
    ) {
        self.version = version
        self.projectName = projectName
        self.device = device
        self.tempo = tempo
        self.baseOctave = baseOctave
        self.key = key
        self.patterns = patterns
        self.instruments = instruments
    }

    /// JSON bytes for writing to disk.
    public func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Reads a document, refusing one written by a newer build rather than
    /// silently dropping whatever it does not understand.
    public static func decoded(from data: Data) throws -> ProjectFile {
        let file: ProjectFile
        do {
            file = try JSONDecoder().decode(ProjectFile.self, from: data)
        } catch {
            throw DocumentError.unreadable
        }
        guard file.version <= currentVersion else {
            throw DocumentError.newerVersion(file.version)
        }
        return file
    }

    public enum DocumentError: Error, Equatable, LocalizedError {
        case unreadable
        case newerVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .unreadable:
                return "This is not a Patternaut document, or it is damaged."
            case .newerVersion(let version):
                return "This document was saved by a newer version of Patternaut (format \(version))."
            }
        }
    }
}
