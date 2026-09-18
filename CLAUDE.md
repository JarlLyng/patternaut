# CLAUDE.md — Patternaut

Quick-start context for developers and AI assistants. Detailed technical notes in
`PatternautCore/README.md`.

## What is Patternaut?

Patternaut is a native macOS companion app for the Polyend Tracker+ and Tracker Mini. It
generates, mutates and shapes tracker patterns on the Mac, then gets them onto the hardware
(byte-exact SD-card files, or live MIDI). It runs locally: no accounts, no cloud, no tracking.

- **Developer:** Jarl Lyng / [IAMJARL](https://iamjarl.com)
- **Website:** [patternaut.iamjarl.com](https://patternaut.iamjarl.com)
- **License:** [MIT](LICENSE) — open source (repo currently private during beta).
- **Price:** one-time purchase, no subscription (exact price not decided yet).
- **Status:** private TestFlight beta, v0.3.0 (macOS).
- **Sister apps:** the IAMJARL music tools (It's mono, yo!, It's 404, yo!, Echolume, TonVault).

## Strategy lives in the private hub

Target audience, positioning, pricing reasoning, SEO/ASO playbooks, trademark and competitor
analysis are **not** in this repo. They live in the private
[iamjarl-strategy](https://github.com/JarlLyng/iamjarl-strategy) hub (folder `Patternaut/`).
Before any audience/positioning/pricing/marketing or public-copy work, read that repo's
`CONVENTIONS.md`, `VOICE.md` and `SEO_GUIDANCE.md`, and write results there, not here.

## Layout

- `PatternautCore/` — Swift package (the engine): device-neutral pattern model, device
  profiles, generators, mutation, editor logic, MIDI sequencing, and byte-exact `.mtp`/`.mt`/
  `.pti` export. Pure, unit-tested (`swift test`).
- `App/` — the macOS SwiftUI app (Xcode project generated from `App/project.yml` via
  **xcodegen**). Depends on `PatternautCore`.
- `docs/` — the marketing site source (GitHub Pages → patternaut.iamjarl.com).

## App features (be precise — do not invent features that don't exist)

- Many patterns per document, with a pattern bar to switch/add/duplicate/remove/name them; export
  writes them all with a playlist in that order. Import reads a Tracker project folder back
  (`ProjectBundleReader`): patterns, pattern names, track names, tempo and `.pti` instruments
  with their audio. Verified by reading
  every project on a real card: 47 projects, 538 patterns, including ones from older firmware.
- A document app: work is saved as `.patternaut` (JSON, UTI `com.iamjarl.patternaut.project`),
  holding the pattern, settings, seed and the loaded samples as canonical WAVs. `DocumentGroup`
  + `ReferenceFileDocument`, so Save/Open/recents/autosave are the system's. Editing registers
  with the window's `UndoManager`, which is also what marks the document as changed.
- Device-neutral pattern model with Tracker Mini / Tracker+ device profiles (16 tracks).
- Keyboard-first grid editor: cursor navigation, note/instrument entry, editable track names,
  undo/redo, and full
  per-step FX entry on both lanes (all 42 effects from the device's FX set, typed by their
  device symbol or picked from an FX menu, with values shown in the same scaled ranges the
  Tracker shows, e.g. Panning as -50 to +50).
- Generators, all reproducible from a seed: whole beats (kick/snare/hat plus optional
  probability percussion and bass), Euclidean rhythms, probability, swing, humanize,
  rotate/reverse transforms. Generate rolls a new seed each press; the seed is stored with the
  pattern and shown in the app. Pattern length (8-128 steps) and key/scale (eleven scales, any
  root) are set in the app and drive generation; pitched parts stay in key, drums are unaffected.
- Mutation: subtle / moderate / strong / chaotic.
- Byte-exact hardware export verified against the official `polyend/tracker-lib`: `.mtp`
  patterns, `.mt` projects, `.pti` instruments and `patterns/patternsMetadata`, written as a
  loadable SD-card project folder (`project.mt` + lowercase `patterns/` and `instruments/`).
- Sample loading: WAV becomes a `.pti` instrument, by file picker or drag and drop. 8/16/24/32-bit
  integer and 32/64-bit float are converted to the 16-bit 44.1 kHz PCM the device stores;
  other sample rates are resampled (linear interpolation).
- Diagnostics: unified logging (`os.Logger`, subsystem `com.iamjarl.patternaut`) + an in-app
  log panel with copy (categories: export, samples, app).

### Features that do NOT exist (common hallucination targets)
- No audio engine and no in-app sample playback / preview.
- No whole-pattern live MIDI. Sending is per track, by design of the hardware.
- No `.mtp`/`.mt` import UI (the core can read `.mtp`, but there is no import flow yet).
- The `.mt` project's instrument pool comes from a template, so loaded samples are NOT
  auto-assigned to instrument slots on the device yet.
- No song/arrangement mode beyond a linear playlist of the document's patterns.
- Reading a `.pti` the device wrote and writing it back differs in three fields this model does
  not carry (the old extension left after the name's terminator, the reserved bytes at offset 56,
  and `FF FF` end padding). `tracker-lib` writes those the same way Patternaut does.
- No account, cloud, sync, analytics, ads, or subscription.
- Not a full software tracker and not a replacement for the hardware. No song/arrangement mode.
- macOS only. No iOS/iPad version.
- No AI features inside the shipped app.
- **No live MIDI output in the app.** It was removed on 2026-09-18: the SD-card route carries FX,
  track names and samples and is verified on hardware, while MIDI reached one track at a time
  with pitch and velocity only. `MIDISequencer` stays in the core, tested, as the basis for a
  possible MIDI file export for DAWs.

## Requirements
- macOS 14 or later. Xcode 26 toolchain, `xcodegen` for regenerating the app project.

## Build & run
- Core + tests: `cd PatternautCore && swift test`.
- App: `cd App && xcodegen generate` then open `Patternaut.xcodeproj`, or
  `xcodebuild -project App/Patternaut.xcodeproj -scheme Patternaut -destination 'platform=macOS' build`.
- The committed `Patternaut.xcodeproj` is what Xcode Cloud builds (from the `release` branch);
  regenerate it with xcodegen after changing `App/project.yml` or adding source files.

## Conventions
- Privacy-first: the only telemetry permitted is anonymous crash reporting (none today).
- Design: adopting `iamjarl-design` tokens is a TODO (the app and site currently use their
  own styles).
- Branches: app changes go to `main` and `release`; docs/site-only changes go to `main` only
  (so they don't trigger Xcode Cloud app builds).
