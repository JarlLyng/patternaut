import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Writes a complete, hardware-loadable project folder to disk:
///
/// ```
/// <root>/<ProjectName>/
///     project.mt
///     patterns/pattern_01.mtp, pattern_02.mtp, …
///     patterns/patternsMetadata
///     instruments/1 <name>.pti, 2 <name>.pti, …
/// ```
///
/// This is the concrete "Vej B" deliverable — drop the folder onto an SD card's
/// `/Projects` directory and open it on a Tracker Mini 2.0 / Tracker+.
///
/// The folder and file names follow what `tracker-lib` reads back: lowercase
/// `patterns/` and `instruments/`, and a `patternsMetadata` beside the patterns,
/// which that library treats as essential and refuses to load a project without.
///
/// Instrument files carry their slot in the filename, as a 1-based number
/// followed by a space (`4 kick_zapper.pti` is instrument index 3 in a pattern).
/// That is the convention the device itself uses, read off a real card, so the
/// instrument numbers in an exported pattern line up with the samples without
/// anyone reassigning them by hand.
public enum ProjectBundleWriter {
    public struct Result: Sendable, Equatable {
        public let projectDirectory: URL
        public let projectFile: URL
        public let patternFiles: [URL]
        public let metadataFile: URL
        public let instrumentFiles: [URL]
    }

    /// A named instrument to write into the project's `Instruments` folder.
    public struct NamedInstrument: Sendable {
        public let name: String
        public let instrument: Instrument
        public init(name: String, instrument: Instrument) {
            self.name = name
            self.instrument = instrument
        }
    }

    /// Strips the extended attributes a sandboxed macOS app leaves on written
    /// files (quarantine, provenance) and deletes the `._name` companion the
    /// filesystem creates for them on a FAT card. No-op off Apple platforms.
    private static func stripMacMetadata(from url: URL, fileManager: FileManager) {
        #if canImport(Darwin)
        url.withUnsafeFileSystemRepresentation { pointer in
            guard let pointer else { return }
            let length = listxattr(pointer, nil, 0, XATTR_NOFOLLOW)
            guard length > 0 else { return }
            var buffer = [CChar](repeating: 0, count: length)
            guard listxattr(pointer, &buffer, length, XATTR_NOFOLLOW) > 0 else { return }
            for name in buffer.split(separator: 0).map({ String(cString: Array($0) + [0]) }) {
                _ = removexattr(pointer, name, XATTR_NOFOLLOW)
            }
        }
        let companion = url.deletingLastPathComponent()
            .appendingPathComponent("._" + url.lastPathComponent)
        try? fileManager.removeItem(at: companion)
        #endif
    }

    /// Writes `patterns` and a `project.mt` whose song plays them in order.
    ///
    /// - Parameters:
    ///   - patterns: One `Pattern` per `.mtp` file, written as `Pattern_01`…`Pattern_NN`.
    ///     Each should have the device's full track count (validated by the caller).
    ///   - root: Directory to create the project folder in (e.g. `<SD>/Projects`).
    @discardableResult
    public static func write(
        patterns: [Pattern],
        projectName: String,
        device: DeviceModel,
        tempo: Float = 130,
        instruments: [NamedInstrument] = [],
        to root: URL,
        options: MTPExportOptions = .default,
        fileManager: FileManager = .default
    ) throws -> Result {
        let projectDir = root.appendingPathComponent(projectName, isDirectory: true)
        let patternsDir = projectDir.appendingPathComponent("patterns", isDirectory: true)
        try fileManager.createDirectory(at: patternsDir, withIntermediateDirectories: true)

        // Instruments folder (.pti files), only if any provided.
        var instrumentURLs: [URL] = []
        if !instruments.isEmpty {
            let instrumentsDir = projectDir.appendingPathComponent("instruments", isDirectory: true)
            try fileManager.createDirectory(at: instrumentsDir, withIntermediateDirectories: true)
            for (index, named) in instruments.enumerated() {
                // Slot numbers in filenames are 1-based; pattern instrument
                // indices are 0-based, so slot N + 1 is instrument N.
                let url = instrumentsDir.appendingPathComponent("\(index + 1) \(named.name).pti")
                try named.instrument.data().write(to: url)
                instrumentURLs.append(url)
            }
        }

        // Pattern files: pattern_01.mtp, pattern_02.mtp, …
        var patternURLs: [URL] = []
        for (index, pattern) in patterns.enumerated() {
            let name = String(format: "pattern_%02d.mtp", index + 1)
            let url = patternsDir.appendingPathComponent(name)
            try MTPExporter.export(pattern, options: options).write(to: url)
            patternURLs.append(url)
        }

        // patternsMetadata: the pattern slot names, which the project needs to load.
        let metadata = PatternsMetadata(patternNames: patterns.map { $0.metadata.name })
        let metadataFile = patternsDir.appendingPathComponent("patternsMetadata")
        try metadata.data().write(to: metadataFile)

        // project.mt with a linear song playlist referencing the patterns.
        var project = MTProject.new(name: projectName, device: device)
        project.globalTempo = tempo
        var playlist = [UInt8](repeating: 0, count: TrackerFormat.songSlots)
        for i in 0..<min(patterns.count, TrackerFormat.songSlots) {
            playlist[i] = UInt8(i + 1) // Pattern number is 1-based.
        }
        project.playlist = playlist

        let projectFile = projectDir.appendingPathComponent("project.mt")
        try project.data().write(to: projectFile)

        // macOS keeps a file's extended attributes on a FAT card in a companion
        // "._name" file. The Tracker reads everything in patterns/, so those
        // companions would turn up as junk patterns. Remove both.
        // Directories get companions too, so clean those alongside the files.
        var written = patternURLs + instrumentURLs + [projectFile, metadataFile, patternsDir, projectDir]
        if !instrumentURLs.isEmpty {
            written.append(instrumentURLs[0].deletingLastPathComponent())
        }
        for url in written {
            stripMacMetadata(from: url, fileManager: fileManager)
        }

        return Result(projectDirectory: projectDir, projectFile: projectFile, patternFiles: patternURLs,
                      metadataFile: metadataFile, instrumentFiles: instrumentURLs)
    }
}
