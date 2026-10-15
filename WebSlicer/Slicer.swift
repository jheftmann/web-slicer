import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reads an image, scales it per the plan, and writes each slice as a PNG into a new folder
/// next to the source. Pixels are cropped straight out of the image, never redrawn, so slices
/// restack to the exact source (or exact scaled image).
enum Slicer {
    struct Output: Sendable {
        let folder: URL
        let files: [URL]
        let plan: SlicePlan
    }

    enum Failure: LocalizedError {
        case notAnImage(URL)
        case unreadable(URL)
        case writeFailed(URL)

        var errorDescription: String? {
            switch self {
            case .notAnImage(let url): "\(url.lastPathComponent) isn't an image."
            case .unreadable(let url): "Couldn't read \(url.lastPathComponent)."
            case .writeFailed(let url): "Couldn't write \(url.lastPathComponent)."
            }
        }
    }

    static func isImage(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .image) ?? false
    }

    static func slice(_ url: URL, maxWidth: Int, sliceHeight: Int) throws -> Output {
        guard isImage(url) else { throw Failure.notAnImage(url) }
        let source = try loadImage(at: url)
        let plan = SlicePlan(sourceWidth: source.width, sourceHeight: source.height,
                             maxWidth: maxWidth, sliceHeight: sliceHeight)
        let image = try render(source, plan: plan)

        let name = url.deletingPathExtension().lastPathComponent
        let folder = uniqueFolder(named: "\(name) slices", in: url.deletingLastPathComponent())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)

        let digits = max(2, String(plan.slices.count).count)
        let files = try plan.slices.enumerated().map { index, rect in
            let number = String(repeating: "0", count: digits - String(index + 1).count) + String(index + 1)
            let file = folder.appending(path: "\(name)-\(number).png")
            // CGImage cropping uses a top-left origin, matching the plan's minY.
            let bounds = CGRect(x: 0, y: rect.minY, width: rect.width, height: rect.height)
            guard let piece = image.cropping(to: bounds) else { throw Failure.writeFailed(file) }
            try writePNG(piece, to: file)
            return file
        }
        return Output(folder: folder, files: files, plan: plan)
    }

    /// Decodes the first frame, applying EXIF orientation so photos aren't sliced sideways.
    static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { throw Failure.unreadable(url) }

        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let image: CGImage?
        if orientation == 1 {
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        } else {
            let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            ] as CFDictionary)
        }
        guard let image else { throw Failure.unreadable(url) }
        return image
    }

    /// Returns the image at the plan's output size, keeping its color space. Unscaled images pass through untouched.
    static func render(_ image: CGImage, plan: SlicePlan) throws -> CGImage {
        guard plan.isScaled else { return image }
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: plan.outputWidth, height: plan.outputHeight,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw Failure.unreadable(URL(filePath: "scaled image")) }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: plan.outputWidth, height: plan.outputHeight))
        guard let scaled = context.makeImage() else { throw Failure.unreadable(URL(filePath: "scaled image")) }
        return scaled
    }

    /// "<name> slices", then "<name> slices 2", "3", … — never an existing folder.
    static func uniqueFolder(named base: String, in parent: URL) -> URL {
        var candidate = parent.appending(path: base, directoryHint: .isDirectory)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = parent.appending(path: "\(base) \(n)", directoryHint: .isDirectory)
            n += 1
        }
        return candidate
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw Failure.writeFailed(url) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.writeFailed(url) }
    }
}
