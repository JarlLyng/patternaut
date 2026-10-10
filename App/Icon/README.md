# App icon

An SD card with a step pattern on it: the app makes patterns and puts them on the card. It is
drawn the way the other IAMJARL Mac apps are: one `#D0FF00` line figure on black, one stroke
weight, flat, no gradients or glass.

## What ships

`../Patternaut/AppIcon.icon` is an Icon Composer document and is what Xcode builds. It has one
layer, `glyph.svg`, on a solid black fill, with shadow, translucency and specular highlights off so
it stays flat. The tinted appearance swaps in `glyph-tinted.svg`, a white copy the system colours.
Light and dark are the same icon, as with the sister apps. Xcode flattens the document into the
`.icns` that macOS 14 and 15 show, so the asset catalog's `AppIcon.appiconset` is not used by the
build; it carries the same icon, rendered from `icon.svg` here, for anything that reads the catalog.

## Checking a change

Icon Composer's command-line tool renders any appearance without opening the app:

```bash
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ICTOOL" App/Patternaut/AppIcon.icon --export-image --output-file default.png \
  --platform macOS --rendition Default --width 512 --height 512 --scale 1
```

Renditions: `Default`, `Dark`, `TintedLight`, `TintedDark`.

## Rendering `icon.svg` for the asset catalog

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,1024 --screenshot=icon.png "file://$PWD/icon.svg"
```

Then `sips -z <n> <n> icon.png` for each size in `AppIcon.appiconset`.
