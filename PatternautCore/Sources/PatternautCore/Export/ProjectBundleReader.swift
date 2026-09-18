import Foundation

/// Reads a Tracker project folder back into the model: the counterpart of
/// ``ProjectBundleWriter``.
///
/// This is what makes the app useful on work that already exists. Patterns come
/// from `patterns/*.mtp`, their names from `patterns/patternsMetadata`, and the
/// tempo and track names from `project.mt`, since a pattern file carries
/// neither.
///
/// - Note: `.pti` instruments are not read; the format is written but not yet
///   parsed, so an imported project arrives without its audio.
public enum ProjectBundleReader {
    public struct Result: Sendable, Equatable {
        public let projectName: String
        public let tempo: Double
        public let patterns: [Pattern]
        /// Names of the `.pti` files found, in slot order. Not loaded as audio.
        public let instrumentNames: [String]
    }

    public enum ReadError: Error, Equatable, LocalizedError {
        case notAProject(String)
        case noPatterns

        public var errorDescription: String? {
            switch self {
            case .notAProject(let name):
                return "\(name) does not look like a Tracker project (no project.mt)."
            case .noPatterns:
                return "That project has no pattern files."
            }
        }
    }

    /// Reads the project folder at `url`.
    ///
    /// - Parameter device: Which profile to attach to the patterns. The files
    ///   themselves only imply a track count, not a model.
    public static func read(
        at url: URL,
        device: DeviceModel = .trackerPlus,
        fileManager: FileManager = .default
    ) throws -> Result {
        let projectFile = try locate("project.mt", in: url, fileManager: fileManager)
        guard let projectFile else { throw ReadError.notAProject(url.lastPathComponent) }
        let project = try MTProjectImporter.parse(Data(contentsOf: projectFile))

        guard let patternsDir = try directory(named: "patterns", in: url, fileManager: fileManager) else {
            throw ReadError.noPatterns
        }

        // Pattern slot names, when the project has them.
        var names: [String] = []
        if let metadataURL = try locate("patternsMetadata", in: patternsDir, fileManager: fileManager),
           let metadata = try? PatternsMetadata.parse(Data(contentsOf: metadataURL)) {
            names = metadata.patternNames
        }

        let patternURLs = try fileManager.contentsOfDirectory(at: patternsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "mtp" && !$0.lastPathComponent.hasPrefix("._") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard !patternURLs.isEmpty else { throw ReadError.noPatterns }

        let patterns = try patternURLs.enumerated().map { index, patternURL -> Pattern in
            let document = try MTPImporter.parse(Data(contentsOf: patternURL))
            let fallback = patternURL.deletingPathExtension().lastPathComponent
            let slotName = index < names.count && !names[index].isEmpty ? names[index] : fallback
            var pattern = document.makePattern(
                device: device, name: slotName, tempo: Double(project.globalTempo)
            )
            // Track names live in project.mt, so put them back on the tracks.
            for trackIndex in pattern.tracks.indices where trackIndex < project.trackNames.count {
                let name = project.trackNames[trackIndex]
                if !name.isEmpty { pattern.tracks[trackIndex].name = name }
            }
            return pattern
        }

        var instrumentNames: [String] = []
        if let instrumentsDir = try directory(named: "instruments", in: url, fileManager: fileManager) {
            instrumentNames = try fileManager.contentsOfDirectory(at: instrumentsDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "pti" && !$0.lastPathComponent.hasPrefix("._") }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        let name = project.projectName.isEmpty ? url.lastPathComponent : project.projectName
        return Result(projectName: name, tempo: Double(project.globalTempo),
                      patterns: patterns, instrumentNames: instrumentNames)
    }

    // MARK: - Private

    /// Finds a file by name, case-insensitively: cards written on different
    /// systems disagree about capitalisation.
    private static func locate(_ name: String, in directory: URL, fileManager: FileManager) throws -> URL? {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents.first { $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func directory(named name: String, in parent: URL, fileManager: FileManager) throws -> URL? {
        guard let match = try locate(name, in: parent, fileManager: fileManager) else { return nil }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: match.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return match
    }
}
