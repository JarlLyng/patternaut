import Foundation

/// Writes a complete, hardware-loadable project folder to disk:
///
/// ```
/// <root>/<ProjectName>/
///     project.mt
///     patterns/pattern_01.mtp, pattern_02.mtp, …
///     patterns/patternsMetadata
///     instruments/<name>.pti
/// ```
///
/// This is the concrete "Vej B" deliverable — drop the folder onto an SD card's
/// `/Projects` directory and open it on a Tracker Mini 2.0 / Tracker+.
///
/// The folder and file names follow what `tracker-lib` reads back: lowercase
/// `patterns/` and `instruments/`, and a `patternsMetadata` beside the patterns,
/// which that library treats as essential and refuses to load a project without.
///
/// - Note: The project's instrument pool comes from the embedded `.mt` template.
///   The `.pti` files are written into the project, but which slot each one
///   occupies is still assigned on the device.
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
            for named in instruments {
                let url = instrumentsDir.appendingPathComponent("\(named.name).pti")
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

        return Result(projectDirectory: projectDir, projectFile: projectFile, patternFiles: patternURLs,
                      metadataFile: metadataFile, instrumentFiles: instrumentURLs)
    }
}
