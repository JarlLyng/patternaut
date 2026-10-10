# App icon

An SD card carrying a sixteen-step pattern: the app makes patterns and puts them on the card. The
card's cut corner is what keeps it recognisable at Dock sizes.

The SVGs here are the source. The PNGs in `../Patternaut/Assets.xcassets/AppIcon.appiconset` are
rendered from them; nothing in this folder is built into the app.

| File | Use |
|---|---|
| `icon-dark.svg` | The app icon, 64 px and up |
| `icon-dark-small.svg` | 16 and 32 px: the silhouette and a bold two-by-two pattern, since the contacts and sixteen cells turn to noise that small |
| `icon-light.svg`, `icon-tinted.svg` | Light and tinted appearances, kept for Icon Composer and the design file. The asset catalog ships the dark icon only |

The shape follows the macOS template: a 1024 canvas with the rounded square at 824, inset 100,
transparent outside it. The accent is `#D0FF00`, the same as the site and the App Store posters.

## Rendering

Any SVG renderer that keeps transparency will do. With Chrome:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,1024 --default-background-color=00000000 \
  --screenshot=icon-dark.png "file://$PWD/icon-dark.svg"
```

Then scale with `sips -z <n> <n>` into the asset catalog: `icon-dark.png` for 64 to 1024,
`icon-dark-small.png` for 16 and 32.
