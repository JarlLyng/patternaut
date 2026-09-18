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
        /// The instruments found, in slot order.
        public let instruments: [ImportedInstrument]
        /// Names of the `.pti` files found, in slot order.
        public var instrumentNames: [String] { instruments.map(\.name) }
        /// What could not be read but did not stop the import.
        public let warnings: [String]
    }

    /// Used when a project's own settings cannot be read.
    public static let defaultTempo: Double = 130

    /// An instrument read off the card. `name` has the device's slot prefix
    /// removed, because the slot is this entry's position in the list; writing
    /// the project back puts the prefix on again.
    public struct ImportedInstrument: Sendable, Equatable {
        public let name: String
        public let instrument: Instrument
    }

    public enum ReadError: Error, Equatable, LocalizedError {
        case notAProject(String)
        case noPatterns

        public var errorDescription: String? {
            switch self {
            case .notAProject(let name):
                return "\"\(name)\" is not a Tracker project. Choose the project folder itself, the one holding project.mt."
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
        at selection: URL,
        device: DeviceModel = .trackerPlus,
        fileManager: FileManager = .default
    ) throws -> Result {
        let url = try projectRoot(for: selection, fileManager: fileManager)
            ?? { throw ReadError.notAProject(selection.lastPathComponent) }()
        guard let projectFile = try locate("project.mt", in: url, fileManager: fileManager) else {
            throw ReadError.notAProject(selection.lastPathComponent)
        }

        // Projects from older firmware have a smaller, differently laid out
        // project.mt (1284 or 1572 bytes against today's 2324). The patterns
        // themselves are still readable, so a project like that is imported
        // without its tempo and track names rather than refused.
        var project: MTProject?
        var warnings: [String] = []
        do {
            project = try MTProjectImporter.parse(Data(contentsOf: projectFile))
        } catch {
            warnings.append("Its project.mt is from an older firmware, so the tempo and track names could not be read.")
        }

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

        let tempo = project.map { Double($0.globalTempo) } ?? defaultTempo
        let patterns = try patternURLs.enumerated().map { index, patternURL -> Pattern in
            let document = try MTPImporter.parse(Data(contentsOf: patternURL))
            let fallback = patternURL.deletingPathExtension().lastPathComponent
            let slotName = index < names.count && !names[index].isEmpty ? names[index] : fallback
            var pattern = document.makePattern(
                device: device, name: slotName, tempo: tempo
            )
            // Track names live in project.mt, so put them back on the tracks.
            if let names = project?.trackNames {
                for trackIndex in pattern.tracks.indices where trackIndex < names.count {
                    let name = names[trackIndex]
                    if !name.isEmpty { pattern.tracks[trackIndex].name = name }
                }
            }
            // Files from the 8-track era arrive short. Pad them to the profile
            // so the pattern can be edited and written back out for this device.
            let profile = device.profile
            if pattern.tracks.count < profile.trackCount {
                let names = profile.defaultTrackNames
                for index in pattern.tracks.count..<profile.trackCount {
                    pattern.tracks.append(Track.empty(
                        name: names[index], role: profile.role(forTrack: index),
                        length: pattern.tracks.first?.length ?? 16
                    ))
                }
            }
            return pattern
        }

        var instruments: [ImportedInstrument] = []
        if let instrumentsDir = try directory(named: "instruments", in: url, fileManager: fileManager) {
            let files = try fileManager.contentsOfDirectory(at: instrumentsDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "pti" && !$0.lastPathComponent.hasPrefix("._") }
                // The device prefixes the slot number, so sorting by name in
                // number order puts each instrument back in its own slot.
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            for file in files {
                let label = file.deletingPathExtension().lastPathComponent
                do {
                    let instrument = try PTIImporter.parse(try Data(contentsOf: file))
                    instruments.append(ImportedInstrument(name: withoutSlotPrefix(label), instrument: instrument))
                } catch {
                    warnings.append("Could not read the instrument \"\(label)\": \(error.localizedDescription)")
                }
            }
        }

        // Old projects keep their audio as plain WAVs in a samples folder.
        if try directory(named: "samples", in: url, fileManager: fileManager) != nil {
            warnings.append("Its samples are in a samples folder, which Patternaut does not read.")
        }
        if let first = patterns.first, first.tracks.count == device.profile.trackCount,
           patternURLs.count > 0, wasShort(patternURLs[0], device: device) {
            warnings.append("It was made for 8 tracks; the extra tracks are empty.")
        }

        let name = project.map { $0.projectName.isEmpty ? url.lastPathComponent : $0.projectName }
            ?? url.lastPathComponent
        return Result(projectName: name, tempo: tempo, patterns: patterns,
                      instruments: instruments, warnings: warnings)
    }

    // MARK: - Private

    /// Drops the device's slot number from an instrument filename, so
    /// "4 kick_zapper" reads as "kick_zapper".
    private static func withoutSlotPrefix(_ name: String) -> String {
        let parts = name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, Int(parts[0]) != nil, !parts[1].isEmpty else { return name }
        return String(parts[1])
    }

    /// Finds the project folder from whatever was picked. Landing inside
    /// `patterns` or on a file in it is an easy mistake, and the folder above is
    /// unambiguous, so there is no reason to refuse.
    private static func projectRoot(for url: URL, fileManager: FileManager) throws -> URL? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        let directory = isDirectory.boolValue ? url : url.deletingLastPathComponent()

        if try locate("project.mt", in: directory, fileManager: fileManager) != nil { return directory }
        let parent = directory.deletingLastPathComponent()
        if parent != directory, try locate("project.mt", in: parent, fileManager: fileManager) != nil {
            return parent
        }
        return nil
    }

    /// True when the file on disk holds fewer tracks than the device profile.
    private static func wasShort(_ url: URL, device: DeviceModel) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let document = try? MTPImporter.parse(data) else { return false }
        return document.tracks.count < device.profile.trackCount
    }

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
