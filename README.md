<img src="docs/icon.png" width="128" alt="Web Slicer icon">

# Web Slicer

A tiny macOS app that cuts tall images — like full-page screenshots — into slices that fit
Figma's 4096px image limit. Drop an image, get a folder of PNGs that stack back together
with no gaps, no overlaps and no lost pixels.

**[Download Web Slicer for macOS](https://github.com/jheftmann/web-slicer/releases/latest/download/Web-Slicer.zip)** · requires macOS 26 (Tahoe) or later · Apple Silicon and Intel

## How it works

1. Drop one or more images on the window (or click it, or press ⌘O).
2. Web Slicer creates a `<name> slices/` folder next to each image and opens it in Finder.

Two settings sit at the bottom of the window:

- **Width (scale)** — images wider than this are scaled down proportionally first. Default 4096.
  Images are never scaled up.
- **Height (slice)** — the height of each slice. Default 4096. The last slice holds whatever is left.

Sizes are real image pixels, so a Retina screenshot of a 1440pt-wide window is 2880px wide.
Slices are always PNG and keep the original color profile (Display P3 stays P3).

## Install

1. [Download the latest release](https://github.com/jheftmann/web-slicer/releases/latest/download/Web-Slicer.zip) and unzip it.
2. Move **Web Slicer.app** to your Applications folder.
3. Open it. Because the app isn't notarized by Apple, macOS will block it the first time — click **Done**.
4. Open **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, and confirm.

You only need to do this once. If you prefer Terminal, this clears the block instead:

```bash
xattr -dr com.apple.quarantine "/Applications/Web Slicer.app"
```

## Build from source

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
xcodebuild test -scheme WebSlicer -destination 'platform=macOS'
```

```bash
xcodebuild -scheme WebSlicer -configuration Release -derivedDataPath build build
```

The app lands in `build/Build/Products/Release/Web Slicer.app`. See [docs/spec.md](docs/spec.md) for the
full behavior and [docs/testing.md](docs/testing.md) for the manual release checklist.

## Changelog

### 1.0.0 — 2026-10-15

- First release.
- Drag-and-drop slicing into fixed-height PNGs, with batch support.
- Width (scale) and Height (slice) settings, remembered between launches.
- Sharp Lanczos downscaling for images wider than the Width setting.
- Color profiles preserved; output never overwrites an existing folder.
- App icon.
