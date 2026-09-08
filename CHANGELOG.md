# Changelog

All notable changes to Patternaut are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims for
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Live MIDI now sends a single track (the one under the cursor) on a selectable channel, instead
  of all tracks on separate channels. The Tracker records incoming MIDI into its currently
  selected track only, so the previous whole-pattern send could not work.

### Added
- `MIDISequencer.events(forTrack:in:channel:)` and a `trackIndices` filter on `events(for:)`.

## [0.1.0] — 2026-07-18
First TestFlight build (macOS, private beta).

### Added
- Device-neutral pattern model with Tracker Mini / Tracker+ profiles (16 tracks).
- Keyboard-first grid editor with undo/redo.
- Generators: Euclidean rhythms, probability, swing, humanize; rotate/reverse transforms.
  All reproducible from a seed.
- Pattern mutation (subtle / moderate / strong / chaotic).
- Byte-exact export to SD card: `.mtp` patterns, `.mt` projects, `.pti` instruments, written
  as a loadable project folder. Verified against the official `polyend/tracker-lib`.
- Live MIDI output via CoreMIDI.
- Sample loading: 16-bit WAV becomes a `.pti` instrument.
- Diagnostics: unified logging plus an in-app log panel.
