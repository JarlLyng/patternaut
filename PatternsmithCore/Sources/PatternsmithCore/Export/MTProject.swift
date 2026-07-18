import Foundation

/// The writable contents of a Polyend `.mt` project file.
///
/// The `.mt` format is only partially reverse-engineered: these are the fields
/// `tracker-lib` reads and writes. Everything else (instrument pool, per-track
/// settings) is preserved from the embedded template on export.
///
/// Patterns and instruments live in separate files (`.mtp`, `.pti`); this is the
/// project manifest — song playlist, tempo, names, and global FX.
public struct MTProject: Sendable, Equatable {
    public var header: Header
    public var projectName: String
    /// Song playlist: 255 slots of pattern numbers (`0` = empty; `1` = Pattern 1).
    public var playlist: [UInt8]
    public var playlistPos: UInt8
    public var globalTempo: Float
    /// 16 track names.
    public var trackNames: [String]
    public var delay: Delay
    public var reverb: Reverb

    public struct Header: Sendable, Equatable {
        public var idFile: String
        public var type: Int
        public var fwVersion: [UInt8]
        public var fileStructureVersion: [UInt8]
        public var size: Int

        public init(idFile: String = "MT", type: Int = 1, fwVersion: [UInt8] = [1, 9, 2, 255],
                    fileStructureVersion: [UInt8] = [17, 17, 17, 17], size: Int = 2324) {
            self.idFile = idFile
            self.type = type
            self.fwVersion = fwVersion
            self.fileStructureVersion = fileStructureVersion
            self.size = size
        }
    }

    public struct Delay: Sendable, Equatable {
        public var feedback: UInt8
        public var time: UInt16
        public var params: UInt8
        public var volume: UInt8
        public var mute: UInt8

        public init(feedback: UInt8 = 50, time: UInt16 = 500, params: UInt8 = 0, volume: UInt8 = 0, mute: UInt8 = 0) {
            self.feedback = feedback
            self.time = time
            self.params = params
            self.volume = volume
            self.mute = mute
        }
    }

    public struct Reverb: Sendable, Equatable {
        public var size: Float
        public var damp: Float
        public var predelay: Float
        public var diffusion: Float
        public var volume: UInt8
        public var mute: UInt8

        public init(size: Float = 0.5, damp: Float = 0.5, predelay: Float = 0.5, diffusion: Float = 0.68,
                    volume: UInt8 = 0, mute: UInt8 = 0) {
            self.size = size
            self.damp = damp
            self.predelay = predelay
            self.diffusion = diffusion
            self.volume = volume
            self.mute = mute
        }
    }

    public init(
        header: Header = Header(),
        projectName: String,
        playlist: [UInt8],
        playlistPos: UInt8 = 0,
        globalTempo: Float = 130,
        trackNames: [String],
        delay: Delay = Delay(),
        reverb: Reverb = Reverb()
    ) {
        self.header = header
        self.projectName = projectName
        self.playlist = playlist
        self.playlistPos = playlistPos
        self.globalTempo = globalTempo
        self.trackNames = trackNames
        self.delay = delay
        self.reverb = reverb
    }

    /// A new empty project matching `tracker-lib` `createProject` defaults:
    /// tempo 130, playlist slot 0 → pattern 1, default track names.
    public static func new(name: String, device: DeviceModel = .trackerPlus) -> MTProject {
        var playlist = [UInt8](repeating: 0, count: TrackerFormat.songSlots)
        playlist[0] = 1
        return MTProject(
            projectName: String(name.prefix(TrackerFormat.projectNameLength)),
            playlist: playlist,
            trackNames: device.profile.defaultTrackNames
        )
    }

    /// Serializes to `.mt` bytes.
    public func data() -> Data { MTProjectExporter.export(self) }
}
