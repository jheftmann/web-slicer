# Manual test checklist

Run before each release, on the Release build. Automated tests cover slice math, seams and pixel fidelity
(`xcodebuild test -scheme WebSlicer -destination 'platform=macOS'`); this list covers the UI.

- [ ] Drop a Retina PNG screenshot taller than 4096px → correct slice count, folder opens in Finder.
- [ ] Drop a Display P3 screenshot → slice colors match the original in Preview.
- [ ] Drop a JPEG → PNG slices produced.
- [ ] Drop an image wider than the Width setting → readout shows the scaled size; slices have that width; small text stays crisp.
- [ ] Drop several images at once → one folder per image.
- [ ] Drop a text file alongside an image → image sliced, "Skipped: …" shown.
- [ ] Drop the same image twice → second run creates `<name> slices 2/`.
- [ ] Type `4` into a field → clamps to 100. Clear a field → resets to 4096.
- [ ] Quit and relaunch → field values remembered.
- [ ] Click the drop zone and ⌘O → file picker opens.
- [ ] App icon shows in the Dock and Finder; Web Slicer → About shows the right version.
