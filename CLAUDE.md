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
- **Status:** private TestFlight beta, v0.1.0 (macOS).
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

- Device-neutral pattern model with Tracker Mini / Tracker+ device profiles (16 tracks).
- Keyboard-first grid editor: cursor navigation, note/instrument entry, undo/redo, and full
  per-step FX entry on both lanes (all 42 effects from the device's FX set, typed by their
  device symbol or picked from an FX menu, with values shown in the same scaled ranges the
  Tracker shows, e.g. Panning as -50 to +50).
- Generators, all reproducible from a seed: Euclidean rhythms, probability, swing, humanize,
  rotate/reverse transforms.
- Mutation: subtle / moderate / strong / chaotic.
- Byte-exact hardware export verified against the official `polyend/tracker-lib`: `.mtp`
  patterns, `.mt` projects, `.pti` instruments, written as a loadable SD-card project folder.
- Live MIDI output (CoreMIDI): send **one track at a time** into the Tracker in record mode. The
  Tracker records incoming MIDI into its currently selected track only, so a whole-pattern
  multi-channel send does not work (community-confirmed, matches the manual).
- Sample loading: 16-bit WAV becomes a `.pti` instrument.
- Diagnostics: unified logging (`os.Logger`, subsystem `com.iamjarl.patternaut`) + an in-app
  log panel with copy.

### Features that do NOT exist (common hallucination targets)
- No audio engine and no in-app sample playback / preview.
- No whole-pattern live MIDI. Sending is per track, by design of the hardware.
- No `.mtp`/`.mt` import UI (the core can read `.mtp`, but there is no import flow yet).
- The `.mt` project's instrument pool comes from a template, so loaded samples are NOT
  auto-assigned to instrument slots on the device yet.
- No account, cloud, sync, analytics, ads, or subscription.
- Not a full software tracker and not a replacement for the hardware. No song/arrangement mode.
- macOS only. No iOS/iPad version.
- No AI features inside the shipped app.
- Hardware round-trip (loading a generated project / receiving live MIDI) is NOT yet verified
  on a physical Tracker.

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
