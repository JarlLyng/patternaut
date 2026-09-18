# Changelog

All notable changes to Patternaut are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims for
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] — 2026-09-19
Third TestFlight build. Work can be saved, projects can be brought in from the card, and a
document holds a whole set of patterns.

### Fixed
- Import accepts whatever you point at inside a project: the `patterns` folder, a `.mtp` file or
  `project.mt` all resolve to the project they belong to, instead of being refused. The panel
  also opens at a mounted Tracker card's Projects folder.
- An untouched document offers the two ways to fill it, Generate and Import, rather than leaving
  an empty grid and no hint that Import is not File > Open.
- Launching opens a blank document instead of an open panel, and a new document starts empty
  rather than pre-filled with a generated beat.
- Importing a Tracker project is now in the File menu as "Import Tracker Project…" (⇧⌘I), next
  to Open. Open takes a Patternaut document; Import takes a folder off the card. Having only a
  toolbar button made the two look like the same thing.
- Validation claimed tracks 9-16 cannot play sample instruments. Polyend's own demo projects do
  exactly that, so the rule was wrong and blocked exporting anything imported from those.
- Validation checked the instrument on steps that play no note. Every empty step in a file
  stores instrument 0, so importing a project raised hundreds of false errors.
- Importing a project from older firmware no longer fails outright: its `project.mt` has a
  different layout, so the patterns are read and the tempo and track names are reported missing.
  Patterns made for 8 tracks are padded to the device's 16.

### Added
- A document holds many patterns, not one. A pattern bar above the grid switches between them,
  adds, duplicates and removes, and names each one; the names are what the Tracker lists.
  Exporting writes them all, with a playlist that plays them in order. Each pattern keeps its
  own undo history.
- Import a Tracker project from an SD card: patterns, their names, the track names and the tempo
  come across. `.pti` audio stays on the card, since the format is written but not yet read.
- Patternaut is a document app. Work is saved to a `.patternaut` file with Save, Open, recent
  documents, autosave and versions, and reopens exactly as it was: pattern, track names, seed,
  key, length, tempo and the loaded samples, which travel inside the document. Until now
  quitting lost everything that had not been exported to a card.
- Undo and redo now run through the window, so the Edit menu names what it will undo
  ("Undo Generate", "Undo Set Effect") and the toolbar no longer needs its own buttons.

## [0.2.0] — 2026-09-18
Second TestFlight build. The SD-card route is now confirmed on real hardware.

### Verified
- A generated project exported to an SD card loads and plays on a Tracker+, with its patterns,
  FX, track names and sample intact. This was the assumption the whole app rested on.

### Changed
- Project folders now use the names `tracker-lib` reads back: lowercase `patterns/` and
  `instruments/`, and `pattern_01.mtp` rather than `Pattern_01.mtp`.
- Sample loading accepts 24-bit, 32-bit and float WAVs, and other sample rates, instead of
  rejecting everything but 16-bit 44.1 kHz. Most sample libraries ship 24-bit, so the old rule
  turned away the majority of a user's own files.
- MIDI destinations now refresh themselves when gear is plugged in or removed, rather than only
  at launch.
- A mutation no longer overwrites the pattern's generator seed; it records `mutationSeed`
  separately, and the app shows both ("Seed 1234, mutated twice").
- Toolbar labels no longer wrap into vertical letters when the window is narrow.
- Generate now makes a different beat every press. It builds a kick, snare and hat, usually
  percussion with Chance on the steps, and often a bass line, with swing and humanising varied
  per seed. The seed is kept with the pattern and shown under the grid, so any beat can be made
  again, and Undo brings back what was there before.
- Live MIDI now sends a single track (the one under the cursor) on a selectable channel, instead
  of all tracks on separate channels. The Tracker records incoming MIDI into its currently
  selected track only, so the previous whole-pattern send could not work.

### Added
- Exported projects now include `patterns/patternsMetadata`, the file that names each pattern
  slot. `tracker-lib` refuses to load a project without it, so its absence may well have been
  enough to stop a generated project loading at all. Byte-verified against that library.
- Pattern length is now editable (8 to 128 steps, or anything the device accepts via the core).
  Changing it resizes the pattern on screen in one undoable step, and is what Generate uses.
- Key and scale for generation: eleven scales, any root. Generated bass lines stay in the key;
  drum tracks trigger samples, so they are unaffected. Same seed in a different key keeps the
  same rhythm.
- `MusicalKey` and `Scale` in the core, with `pitches(from:count:)` and `snap(_:)`.
- `PatternEditor.setLength(_:)`.
- Drag and drop WAVs onto the instruments panel.
- `WavFile.pcm16(_:)`: converts 8/16/24/32-bit integer and 32/64-bit float WAVs to the 16-bit
  44.1 kHz PCM a `.pti` stores, resampling by linear interpolation when the rate differs.
- `BeatGenerator.beat(device:name:tempo:steps:seed:)`: a whole seeded beat, kept inside the
  device's two-FX-per-step budget.
- FX entry in the grid editor. Both FX lanes are now editable: type an effect's device symbol
  (`L` low-pass, `P` panning, `s` delay send) or pick from the FX menu, then type digits to set
  the value, `+`/`-` to nudge by one and `[`/`]` by ten. Delete clears just that lane.
- FX values are shown in the ranges the device shows, not the stored ones, so Panning reads
  -50 to +50 and Tempo 8 to 400.
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
- Sample loading: 16-bit WAV becomes a `.pti` instrument.
- Diagnostics: unified logging plus an in-app log panel.
