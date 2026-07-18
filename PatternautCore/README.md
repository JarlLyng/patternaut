# PatternautCore

Device-neutral model layer for Patternaut. Pure Swift value types, no UI or
persistence dependencies, so it builds and tests standalone (`swift test`) and
can be consumed by the macOS app as a local package.

## Layout

- `Model/` — the internal pattern representation
  - `Pattern` → `Track` → `Step`, plus `Note`, `FX`, `Meter`, `PatternMetadata`
  - Fully `Codable`; `Pattern.jsonData()` / `Pattern.decoded(from:)` give stable
    JSON for backup and sharing.
- `Devices/` — device profiles and format constants
  - `TrackerFormat` — constants ported from the official `tracker-lib`
    (`ProjectConstants`, `PatternConstants`).
  - `DeviceModel` / `DeviceProfile` — `.trackerMini` and `.trackerPlus`, both on
    the shared 16-track format (tracks 1–8 universal, 9–16 MIDI/synth).
- `Validation/` — `DeviceProfile.validate(_:)` reports issues without mutating,
  supporting the "validate before export" principle.
- `Export/` — full hardware I/O, verified byte-for-byte against `tracker-lib`:
  - `MTPExporter` / `MTPImporter` — `.mtp` patterns (round-trips both ways).
  - `MTProjectExporter` / `MTProjectImporter` — `.mt` projects (patches known
    fields into the embedded `MTProjectTemplate`; unknown regions preserved).
  - `Instrument` / `PTIExporter` — `.pti` instruments (16-bit PCM sample +
    playback params, envelopes, LFOs, filter, slices, granular). `WavFile`
    reads/writes the PCM.
  - `ProjectBundleWriter` — writes a loadable `<Project>/project.mt` +
    `Patterns/Pattern_NN.mtp` (+ optional `Instruments/<name>.pti`) folder to
    drop on an SD card.
  - `CRC32` utility (not enabled by default; see below).
- `Generation/` — deterministic, seed-based generators and transforms:
  `SeededGenerator` (SplitMix64), `Euclidean` (Bjorklund), `RhythmGenerator`
  (euclidean + probability), `Groove` (swing, humanize), `Transform` (rotate,
  reverse), and `PatternGenerator.assemble` for device-sized patterns.
- `Editor/` — `PatternEditor` (cursor, navigation, per-step edits, undo/redo)
  and `NoteKeyMap` (tracker keyboard→pitch). Pure, unit-tested logic; the
  SwiftUI layer is a thin shell over it.

The **`PatternautApp`** executable target is a SwiftUI macOS app: a keyboard-
first tracker grid editor with device/tempo controls, a euclidean starter
generator, undo/redo, and SD-card bundle export.

## Verifying `.mtp` export

`MTPExporterTests` compares Swift output against reference `.mtp` files produced
by the official `tracker-lib` writer, stored in `Tests/Fixtures/mtp_vectors.json`.
To regenerate the fixtures (e.g. after a `tracker-lib` update), clone and build
`polyend/tracker-lib`, then run `scratchpad/oracle.mjs <path-to-fixtures>`.

Open questions that need a real device to settle: whether the trailer CRC-32
must be valid (`tracker-lib` and the exporter currently write `0`) and the exact
meaning of the per-track `length` byte.

## Design notes

- **Effects are the source of truth.** Velocity, probability, microtiming and
  gate are stored as effect lanes (`FXType`) and surfaced via convenience
  accessors on `Step`. This matches the hardware (2 FX per step) and makes
  export a near-identity mapping. The 2-FX limit is enforced by validation, not
  hidden.
- **The FX catalog is ported 1:1 from `tracker-lib`** (`FXType.catalog`, 43
  entries, indices 0–42). Treat `tracker-lib` as the authoritative source;
  symbols differ from the original Tracker manual 1.7.0.
- **Profiles are versioned** so firmware differences (effect set, format schema)
  can be tracked over time.

## Running the app

```
swift run PatternautApp
```

Keys: arrows move the cursor; the `z`/`q` rows enter notes (note column); digits
set the instrument; `+`/`-` transpose a semitone, `[`/`]` an octave; delete
clears a step; ⌘Z / ⇧⌘Z undo/redo.

The target builds as a plain SPM executable. For a shippable, sandboxed `.app`
(menus, entitlements, icon), wrap `PatternautCore` in an Xcode app target that
depends on this package — the app sources move over unchanged.

## Not yet built

- `.pti` reading (write is done and verified; import not yet).
- Sample loading UI in the app (the core accepts any 16-bit PCM WAV).
- MIDI import/export and live MIDI recording (Vej A).
- Pattern mutation (subtle/moderate/strong/chaotic).
- An Xcode app target / `.app` bundle for distribution.

Note: a hardware `.mtp` must carry the full device track count (16) — the
device parser infers track count from file size. `PatternGenerator.assemble`
already fills to the full set, and validation warns otherwise.
