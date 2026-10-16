# Web Slicer

Drop a tall image (e.g. a full-page screenshot) and get it cut into PNG slices
no taller than 4096px — Figma's max image size — with no gaps or overlaps.

- **Width (scale)** — images wider than this are scaled down proportionally first (default 4096).
- **Height (slice)** — height of each slice (default 4096). The last slice holds the remainder.
- Output goes to a `<name> slices/` folder next to the original and opens in Finder.

See [docs/spec.md](docs/spec.md) for the full behavior.

## Install (shared builds)

The app is not notarized, so macOS blocks it on first launch.

1. Move `Web Slicer.app` to `/Applications`.
2. Open it once — macOS will say it can't be opened. Click **Done**.
3. Open **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, and confirm.

Or, in Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/Web Slicer.app"
```

## Development

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
```

```bash
xcodebuild test -scheme WebSlicer -destination 'platform=macOS'
```

Build a shareable app:

```bash
xcodebuild -scheme WebSlicer -configuration Release -derivedDataPath build build
```

The app lands in `build/Build/Products/Release/Web Slicer.app`.

## Manual test checklist

- [x] Drop a Retina PNG screenshot taller than 4096px → correct slice count, folder opens in Finder.
- [x] Drop a Display P3 screenshot → slice colors match the original in Preview.
- [x] Drop a JPEG → PNG slices produced.
- [x] Drop an image wider than the Width setting → readout shows the scaled size; slices have that width.
- [x] Drop several images at once → one folder per image.
- [x] Drop a text file alongside an image → image sliced, "Skipped: …" shown.
- [x] Drop the same image twice → second run creates `<name> slices 2/`.
- [x] Type `4` into a field → clamps to 100. Clear a field → resets to 4096.
- [x] Quit and relaunch → field values remembered.
- [x] Click the drop zone and ⌘O → file picker opens.
