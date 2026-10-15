# Web Slicer — Spec

A tiny macOS app: drop an image (usually a long screenshot), get it cut into
fixed-height PNG slices with no gaps or overlaps, ready to import into Figma.

## Phase 1 — Image slicing

### Inputs
- **Drop** one or more files on the drop zone, **click** the drop zone, or **File → Open (⌘O)**.
- Any image format ImageIO reads (PNG, JPEG, HEIC, WebP, TIFF, …).
- Non-image files are skipped and listed in the window ("Skipped: notes.txt").
- Multiple files are processed independently, each into its own folder.

### Settings (one row under the drop zone)
| Field | Default | Meaning |
|---|---|---|
| Width (scale) | 4096 | Max output width. Image is scaled **down** proportionally to this width before slicing. Never upscales. |
| Height (slice) | 4096 | Height of each slice, measured on the (possibly scaled) image. |

- Units are **actual image pixels**, not points. A 2x Retina screenshot of a
  1440pt window is 2880px wide.
- 4096 is Figma's max image dimension on either axis.
- Whole numbers only, minimum 100, no maximum. Empty field resets to 4096.
- Values persist between launches.

### Slicing rules
- Slices are stacked top to bottom with no gap and no overlap. Re-stacking them
  reproduces the (scaled) source exactly.
- The last slice holds the remainder and may be shorter (10,000px tall at 4096 →
  4096, 4096, 1808). No padding, no merging, even for a tiny remainder.
- An image that already fits still exports as a single `-01.png`.

### Output
- Folder created **next to the source file**: `<name> slices/`.
  If it exists, use `<name> slices 2/`, `3/`, … Never overwrite.
- Files: `<name>-01.png`, `<name>-02.png`, … (zero-padded to at least 2 digits,
  more if there are ≥100 slices).
- Always PNG; the source color profile is preserved (P3 stays P3).
- The output folder(s) are revealed in Finder when done.

### Feedback
- After a drop, the label under the icon shows the readout, e.g.
  `2880 × 18,400 px → 5 slices` or
  `5120 × 18,400 → 4096 × 14,720 px → 4 slices`.
- Errors (unreadable file, unwritable folder) are shown in the window, not as modal alerts.

### UI
AppCleaner-style single window: dashed drop zone with icon and label, one row of
two fields beneath. No toolbar, no Settings window in phase 1. Default macOS
components only.

### Testing
- **Slice plan (unit, Swift Testing):** remainder case, fits-in-one, never
  upscale, 5K downscale, rounding at boundaries. A sweep over many size
  combinations asserts slices are contiguous (each `minY` equals the previous
  `maxY`), non-overlapping, and sum to the full height.
- **Pixel round-trip (integration):** synthesize an image where every row has a
  unique color, run the real slicer to disk, read the PNGs back, re-stack, and
  require a byte-exact match. Run in sRGB and Display P3. With scaling, compare
  against the scaled image.
- **Manual checklist:** see README.

## Phase 2 — URL capture (not started)
- URL field in the toolbar; load the page in an offscreen `WKWebView`, snapshot
  full height, feed the result into the same slicer.
- Output to `~/Downloads/<domain> slices/`.
- Known hard parts: lazy-loaded images, sticky headers, cookie banners, auth,
  infinite scroll, memory for very tall pages. To be grilled separately.
