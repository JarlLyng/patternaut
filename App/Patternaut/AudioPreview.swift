import AVFoundation
import Observation
import os
import PatternautCore

/// Lets you hear the pattern on screen through the loaded samples, and a step
/// or a row when you click it. A preview of how it will sound on the Tracker,
/// not the Tracker's engine: ``PreviewRenderer`` says what it plays.
///
/// - Note: `@unchecked Sendable` because the audio is rendered on a queue of
///   its own. What that queue shares with the UI sits behind `shared`; the rest
///   is touched from the main thread only, as in ``EditorModel``.
@Observable
final class AudioPreview: @unchecked Sendable {
    /// What is played. It is read again from the document every tick, so an
    /// edit is heard a moment after it is made.
    struct Program: Sendable {
        var pattern: Pattern
        var tempo: Double
        var samples: [PlayableSample?]
        /// Tells the samples apart without comparing their audio.
        var sampleIDs: [UUID]
    }

    enum PreviewError: LocalizedError {
        case noOutput(String)
        var errorDescription: String? {
            switch self {
            case .noOutput(let reason): "Couldn't start audio output: \(reason)"
            }
        }
    }

    private(set) var isPlaying = false
    /// The row being heard, for the grid to show. `nil` when stopped.
    private(set) var playheadRow: Int?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private let auditionPlayer = AVAudioPlayerNode()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.iamjarl.patternaut.preview", qos: .userInteractive)
    @ObservationIgnored private let shared = OSAllocatedUnfairLock(initialState: Shared())
    @ObservationIgnored private var format: AVAudioFormat?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var programSource: (() -> Program?)?
    @ObservationIgnored private var heardProgram: (pattern: Pattern, tempo: Double, sampleIDs: [UUID])?
    @ObservationIgnored private var lastSound = Date.distantPast
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?

    /// A block is about 46 ms, and four are queued ahead: enough to never run
    /// dry, little enough that an edit is heard within a fifth of a second.
    private static let blockFrames: AVAudioFrameCount = 2_048
    private static let blocksAhead = 4
    /// Audio output is let go after this long with nothing playing.
    private static let idleSeconds = 20.0

    private struct Shared: Sendable {
        var program: Program?
        var renderer = PreviewRenderer(sampleRate: 44_100)
        /// Bumped by every start and stop, so blocks queued for an earlier run
        /// are dropped rather than scheduled.
        var run = 0
        var framesQueued: Int64 = 0
        /// Where each recent block began on the player's timeline.
        var blocks: [(frame: Int64, timing: PreviewRenderer.BlockTiming)] = []
    }

    init() {
        // A new output device stops the engine; stop with it rather than
        // leaving the play button lit over silence.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        timer?.invalidate()
        engine.stop()
    }

    // MARK: - Playing the pattern

    /// Plays the pattern from `row`, looping, and keeps reading `program` so
    /// edits, tempo and sample changes are heard as they happen. Returning
    /// `nil` from `program` stops playback.
    func play(from row: Int, program: @escaping () -> Program?) throws {
        let format = try startEngine()
        guard let initial = program() else { return }
        programSource = program
        heardProgram = (initial.pattern, initial.tempo, initial.sampleIDs)
        let run = shared.withLock { state -> Int in
            state.run += 1
            state.program = initial
            state.renderer = PreviewRenderer(sampleRate: format.sampleRate)
            state.renderer.seek(toStep: Double(row))
            state.framesQueued = 0
            state.blocks = []
            return state.run
        }
        player.stop()
        // Queue the first blocks before starting, so the player's timeline and
        // the pattern's start line up.
        queue.sync {
            for _ in 0..<Self.blocksAhead { scheduleBlock(run: run, format: format) }
        }
        player.play()
        isPlaying = true
        playheadRow = row
        startTimer()
    }

    func stop() {
        shared.withLock { state in
            state.run += 1
            state.program = nil
        }
        player.stop()
        timer?.invalidate()
        timer = nil
        programSource = nil
        heardProgram = nil
        isPlaying = false
        playheadRow = nil
        lastSound = Date()
        scheduleIdleCheck()
    }

    /// Renders the next block and queues it. Runs on `queue`; each block asks
    /// for the next one when the player takes it.
    private func scheduleBlock(run: Int, format: AVAudioFormat) {
        let frames = Int(Self.blockFrames)
        let audio = shared.withLock { state -> StereoAudio? in
            guard state.run == run, let program = state.program else { return nil }
            let audio = state.renderer.render(frames, pattern: program.pattern, tempo: program.tempo,
                                              samples: program.samples)
            state.blocks.append((state.framesQueued, state.renderer.lastBlock))
            if state.blocks.count > 32 { state.blocks.removeFirst(state.blocks.count - 32) }
            state.framesQueued += Int64(frames)
            return audio
        }
        guard let audio, let buffer = Self.buffer(audio, format: format) else { return }
        player.scheduleBuffer(buffer, completionCallbackType: .dataConsumed) { [weak self] _ in
            guard let self else { return }
            self.queue.async { self.scheduleBlock(run: run, format: format) }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        // Common modes, so the row keeps moving while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Picks up changes to the document and moves the playhead. Main thread.
    private func tick() {
        guard isPlaying else { return }
        if let programSource {
            guard let program = programSource() else { stop(); return }
            if heardProgram?.pattern != program.pattern || heardProgram?.tempo != program.tempo
                || heardProgram?.sampleIDs != program.sampleIDs {
                heardProgram = (program.pattern, program.tempo, program.sampleIDs)
                shared.withLock { $0.program = program }
            }
        }
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return }
        let heard = Int64(playerTime.sampleTime)
        let row = shared.withLock { state -> Int? in
            guard let block = state.blocks.last(where: { $0.frame <= heard }) else { return nil }
            let step = block.timing.startStep + Double(heard - block.frame) / block.timing.framesPerStep
            return Int(step) % max(block.timing.length, 1)
        }
        if let row, row != playheadRow { playheadRow = row }
    }

    // MARK: - Clicking a step

    /// Plays `steps` together, once, over whatever was clicked before.
    func audition(_ steps: [(track: Int, step: Step)], samples: [PlayableSample?]) throws {
        let format = try startEngine()
        lastSound = Date()
        queue.async { [weak self] in
            guard let self,
                  let audio = PreviewRenderer.audition(steps, samples: samples, sampleRate: format.sampleRate),
                  let buffer = Self.buffer(audio, format: format) else { return }
            self.auditionPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
            self.auditionPlayer.play()
        }
        scheduleIdleCheck()
    }

    // MARK: - Output

    private func startEngine() throws -> AVAudioFormat {
        if format == nil {
            let output = engine.mainMixerNode.outputFormat(forBus: 0)
            let rate = output.sampleRate > 0 ? output.sampleRate : PlayableSample.sampleRate
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
                throw PreviewError.noOutput("no stereo format at \(Int(rate)) Hz")
            }
            engine.attach(player)
            engine.attach(auditionPlayer)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.connect(auditionPlayer, to: engine.mainMixerNode, format: format)
            self.format = format
        }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                throw PreviewError.noOutput(error.localizedDescription)
            }
        }
        return format!
    }

    /// Lets go of the audio hardware once nothing has played for a while, so
    /// an idle window does not keep it awake.
    private func scheduleIdleCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleSeconds + 0.5) { [weak self] in
            guard let self, !self.isPlaying, self.engine.isRunning,
                  Date().timeIntervalSince(self.lastSound) >= Self.idleSeconds else { return }
            self.engine.pause()
        }
    }

    private static func buffer(_ audio: StereoAudio, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = audio.frameCount
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        audio.left.withUnsafeBufferPointer { channels[0].update(from: $0.baseAddress!, count: frames) }
        audio.right.withUnsafeBufferPointer { channels[1].update(from: $0.baseAddress!, count: frames) }
        return buffer
    }
}
