# Patternaut

A native macOS companion for the Polyend Tracker+ and Tracker Mini. Generate, mutate and
shape patterns on your Mac, then take them to the hardware.

Website: [patternaut.iamjarl.com](https://patternaut.iamjarl.com) · Status: private TestFlight
beta (macOS 14+).

## What it does

- Generators (Euclidean, probability, swing, humanize) and transforms, all reproducible from
  a seed.
- Pattern mutation from subtle to chaotic.
- A keyboard-first tracker grid editor.
- Byte-exact export to SD card as real Tracker files (`.mtp` patterns, `.mt` projects, `.pti`
  instruments), verified against the official [`polyend/tracker-lib`](https://github.com/polyend/tracker-lib).
- Sample loading (WAV becomes a `.pti` instrument; 24-bit and other sample rates are converted).

It runs locally. No account, no cloud, no tracking. It is a companion to the hardware, not a
replacement for it.

## Repository layout

- `PatternautCore/` — the engine, a Swift package (model, generators, mutation, editor logic,
  MIDI sequencing, and file export). Run the tests with `cd PatternautCore && swift test`.
- `App/` — the macOS SwiftUI app. The Xcode project is generated from `App/project.yml` with
  [xcodegen](https://github.com/yonaskolb/XcodeGen): `cd App && xcodegen generate`.
- `docs/` — the marketing site (GitHub Pages).

See [CLAUDE.md](CLAUDE.md) for the developer/assistant quick-start and a precise feature list.

## Strategy

Audience, positioning, pricing and marketing plans live in the private
[iamjarl-strategy](https://github.com/JarlLyng/iamjarl-strategy) hub, not in this repo.

## License

[MIT](LICENSE).

Co-created with AI. Not affiliated with or endorsed by Polyend. Polyend, Tracker, Tracker+ and
Tracker Mini are trademarks of their respective owners.
