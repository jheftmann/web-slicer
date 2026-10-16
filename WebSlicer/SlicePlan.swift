/// A horizontal band of the output image, in pixels. Slices always span the full width.
struct PixelRect: Equatable, Sendable {
    let minY: Int
    let width: Int
    let height: Int
}

/// Pure geometry: given a source size and the two settings, where does every slice go?
/// All values are actual image pixels, never points.
struct SlicePlan: Sendable {
    let sourceWidth: Int
    let sourceHeight: Int
    let outputWidth: Int
    let outputHeight: Int
    let slices: [PixelRect]

    var isScaled: Bool { outputWidth != sourceWidth }

    init(sourceWidth: Int, sourceHeight: Int, maxWidth: Int, sliceHeight: Int) {
        precondition(sourceWidth > 0 && sourceHeight > 0 && maxWidth > 0 && sliceHeight > 0)
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight

        // Downscale only. Height rounds to the nearest pixel, never below 1.
        if sourceWidth > maxWidth {
            outputWidth = maxWidth
            outputHeight = max(1, (sourceHeight * maxWidth + sourceWidth / 2) / sourceWidth)
        } else {
            outputWidth = sourceWidth
            outputHeight = sourceHeight
        }

        let width = outputWidth, height = outputHeight
        slices = stride(from: 0, to: height, by: sliceHeight).map { y in
            PixelRect(minY: y, width: width, height: min(sliceHeight, height - y))
        }
    }

    /// e.g. "2880 × 18,400 px → 5 slices" or "5120 × 18,400 → 4096 × 14,720 px → 4 slices".
    var summary: String {
        let source = "\(Self.format(sourceWidth)) × \(Self.format(sourceHeight))"
        let sizes = isScaled
            ? "\(source) → \(Self.format(outputWidth)) × \(Self.format(outputHeight)) px"
            : "\(source) px"
        let count = slices.count == 1 ? "1 slice" : "\(slices.count) slices"
        return "\(sizes) → \(count)"
    }

    /// Groups thousands only from five digits up, so common widths like 2880 stay compact.
    private static func format(_ n: Int) -> String {
        guard n >= 10_000 else { return String(n) }
        return n.formatted(.number.grouping(.automatic).locale(.init(identifier: "en_US")))
    }
}

/// Rules for the Width and Height fields.
enum PixelSetting {
    static let defaultValue = 4096
    static let minimum = 100

    /// Digits only; empty or digit-less input resets to the default; below the minimum clamps up.
    static func sanitize(_ text: String) -> Int {
        let digits = text.filter(\.isASCII).filter(\.isNumber)
        guard let value = Int(digits.prefix(9)) else { return defaultValue }
        return max(minimum, value)
    }
}
