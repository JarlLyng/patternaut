<img src="App/Patternaut/Assets.xcassets/AppIcon.appiconset/icon_256.png" alt="" width="80" height="80">

# Patternaut

A native Mac companion for the Polyend Tracker+ and Tracker Mini.

<!-- IAMJARL README store block for Patternaut (en). Generated from apps.json, v1.34.0. Do not edit. -->
<p>
  <a href="https://apps.apple.com/app/id6792365053?pt=128512007&amp;ct=github&amp;mt=12"><picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/JarlLyng/iamjarl-design/v1.34.0/badges/mac-app-store-white-en-us.svg">
    <img src="https://raw.githubusercontent.com/JarlLyng/iamjarl-design/v1.34.0/badges/mac-app-store-black-en-us.svg" alt="Download on the Mac App Store" width="156" height="40">
  </picture></a>
  <br>
  $7.99 once · macOS 14 or later · <a href="https://patternaut.iamjarl.com">patternaut.iamjarl.com</a>
</p>

<p>
  <img src="docs/screenshot.png" alt="Patternaut with a generated 32-step beat in C minor on a Tracker+: kick, snare, hat, percussion and bass tracks, and five instruments in slot order." width="640">
</p>

Press Generate and a beat appears: kick, snare, hat, usually percussion carrying the device's own
Chance effect, often a bass line in the key you chose. Every press is different, and every result
is reproducible from its seed. Mutate takes what is there and nudges it, from subtle to chaotic.
Export writes your patterns and samples to the SD card as the files the Tracker already reads.

## What it does

The editor is a tracker grid and works like one: notes on the keyboard rows, sixteen tracks, both
effect lanes per step with the device's own symbols and value ranges, undo on everything.

It reads projects back off the card as well, with their patterns, names, tempo and instruments, so
you can take something you made on the hardware, change it, and write it back without disturbing
the instrument assignments, mixer or effects the machine keeps for itself.

There is no audio engine, so it does not play patterns back. It is a companion to the hardware,
not a replacement for it.

## Feedback

Write to [support@iamjarl.com](mailto:support@iamjarl.com), or use Help > Send Feedback in the app,
which fills in the app and macOS versions. The app took shape in a
[thread on Polyend Backstage](https://backstage.polyend.com/t/thinking-about-a-mac-companion-for-prepping-and-varying-tracker-patterns-worth-building/24944), which is still the best place for ideas other Tracker owners
can weigh in on. Issues here are welcome too.

## For developers

<p>
  <a href="https://madebyhuman.iamjarl.com"><picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://madebyhuman.iamjarl.com/badges/co-created-white.svg">
    <img src="https://madebyhuman.iamjarl.com/badges/co-created-black.svg" alt="Co-created with AI" width="120" height="40"></picture></a>
  <a href="https://github.com/JarlLyng/patternaut/actions/workflows/tests.yml"><img src="https://github.com/JarlLyng/patternaut/actions/workflows/tests.yml/badge.svg" alt="Tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/JarlLyng/patternaut" alt="MIT License"></a>
</p>

### The file formats

The interesting part of this repo is `PatternautCore`, which reads and writes Polyend's formats in
plain Swift with no Apple-only dependencies:

| Format | What it is | Read | Write |
|---|---|---|---|
| `.mtp` | A pattern: 16 tracks of 128 steps | yes | yes |
| `.mt` | The project: tempo, track names, song playlist | yes | yes |
| `.pti` | An instrument: parameters and raw audio | yes | yes |
| `patternsMetadata` | The pattern slot names | yes | yes |

Every writer is verified byte-for-byte against Polyend's own
[`tracker-lib`](https://github.com/polyend/tracker-lib), and then against projects written by the
hardware itself, which is where the interesting differences turned up. Three of them are worth
knowing if you write tools for this device:

- **The per-track length byte is the last step index, not the step count.** Real files use 7, 31,
  63 or 127. Writing the count makes the device read one step too many.
- **The device writes `KS` as the `.mtp` signature, type 2, and the real file size in the header.**
  `tracker-lib`'s own defaults differ (`PM`, type 0, size 0).
- **`patternsMetadata` holds all 256 slots**, whatever the project uses, and the device will not
  load a project without the file.

`ProjectBundleReader` and `ProjectBundleWriter` handle a whole project folder, including stripping
the `._` companion files macOS leaves on a FAT card, which the Tracker otherwise reads as patterns.

### Building

```bash
cd PatternautCore && swift test     # the engine and its tests
cd App && xcodegen generate         # regenerate the Xcode project
open App/Patternaut.xcodeproj
```

The app needs [xcodegen](https://github.com/yonaskolb/XcodeGen); the project file is generated
from `App/project.yml`. `PatternautCore` builds and tests on its own with no Xcode involved.

### Layout

- `PatternautCore/`: the engine, pattern model, device profiles, generators, mutation, editor
  logic, MIDI sequencing and the file formats. Its own [README](PatternautCore/README.md) goes
  into detail.
- `App/`: the macOS SwiftUI app.
- `docs/`: the marketing site, served by GitHub Pages.
- `appstore/`: the App Store posters, and how they are made.

[AGENTS.md](AGENTS.md) is the quick-start for developers and coding agents, and carries a precise
list of what the app does and, just as usefully, what it does not.

### Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

### License

[MIT](LICENSE). Co-created with AI, [how that works](https://madebyhuman.iamjarl.com).

Patternaut is an independent app and is not affiliated with or endorsed by Polyend. Polyend,
Tracker, Tracker+ and Tracker Mini are trademarks of their respective owners.
