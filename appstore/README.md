# App Store posters

Composed with the hub's `tools/appstore_screenshots.py`, which is the portfolio standard: the
capture goes on the brand ground with a headline, at exact slot sizes, using the accent from
`iamjarl-design` rather than a copy of it. The standard itself is written up in the hub's
`DESIGN.md`.

One folder per release. Superseded sets are deleted rather than kept, since git history has them.

## Settings for this app

Dark ground with the `#D0FF00` accent, per the per-app table in `DESIGN.md`: Patternaut sits with
the other music tools. Mac keeps no device bezel, because the capture already carries window
chrome. Captions alternate top and bottom across the set, and `--bleed` is used only on the
top-caption shots, so the crop lands on window chrome rather than on the controls.

## Capturing

The app takes debug-only launch arguments so a capture is repeatable rather than a matter of
clicking in the right order:

```bash
open -a Patternaut.app --args -screenshots -cursor "2,1,fx1"
open -a Patternaut.app "Night Bus.patternaut"
```

`-cursor track,row,column` puts the edit cursor somewhere specific (`note`, `instrument`, `fx1`
or `fx2`), which is how the effect-lane shot shows the hint line under the grid.

Size the window to 1280x800 and capture it by window id, which grabs the window alone whatever is
in front of it:

```bash
screencapture -x -o -l <window id> raw/01-grid.png
```

On a Retina display that produces 2560x1600, which is the `mac` slot exactly.

## Composing

```bash
<hub>/.venv/bin/python <hub>/tools/appstore_screenshots.py compose \
  raw/01-grid.png "A beat to start from
*every time you press it*" appstore/1.0/mac-1.png \
  --slot mac --mode dark --accent "#D0FF00" --caption-pos top --bleed
```

`*phrase*` renders in the accent. Break lines by hand: greedy wrapping orphans the emphasised
phrase, and emphasis cannot span a newline.

## The set

| File | Shows | Caption |
|---|---|---|
| `mac-1.png` | A generated beat, named tracks, instruments in slot order | A beat to start from, *every time you press it* |
| `mac-2.png` | The cursor on an effect lane, with the hint line naming it | Every effect the *device has, in range* |
| `mac-3.png` | An untouched document and the two ways to fill it | Start from nothing, *or from your own card* |
| `mac-4.png` | The keyboard reference | Everything is *on the keyboard* |

The content is a demo document built for the purpose, with audio synthesised rather than taken
from a sample pack, so nothing in the posters belongs to anyone else.

## social-preview.png

GitHub's social preview card, 1280x640, cropped from the first poster. It has to be uploaded by
hand in Settings > General > Social preview: there is no API for it. Without it, a link to the
repo shares as a grey box with the repo name.
