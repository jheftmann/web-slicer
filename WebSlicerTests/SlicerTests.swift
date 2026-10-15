import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import WebSlicer

struct SlicerTests {
    let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory.appending(path: "WebSlicerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: Seams — no dropped or repeated pixels

    @Test(arguments: [CGColorSpace.sRGB as String, CGColorSpace.displayP3 as String])
    func restackedSlicesMatchSourceExactly(spaceName: String) throws {
        let space = try #require(CGColorSpace(name: spaceName as CFString))
        let source = try writeRowCodedPNG(name: "shot", width: 300, height: 1000, space: space)

        let output = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 128)

        #expect(output.files.count == 8) // 7 × 128 + 104
        let slices = try output.files.map(readImage)
        #expect(slices.map(\.height) == [128, 128, 128, 128, 128, 128, 128, 104])
        for slice in slices {
            #expect(slice.width == 300)
            #expect(slice.colorSpace?.name as String? == spaceName)
        }
        let original = try readImage(source)
        #expect(stack(slices, space: space) == bytes(of: original, space: space))
    }

    @Test func restackedScaledSlicesMatchScaledImageExactly() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let source = try writeRowCodedPNG(name: "wide", width: 500, height: 1000, space: space)

        let output = try Slicer.slice(source, maxWidth: 200, sliceHeight: 128)

        #expect(output.plan.outputWidth == 200)
        #expect(output.plan.outputHeight == 400)
        let slices = try output.files.map(readImage)
        #expect(slices.map(\.height) == [128, 128, 128, 16])
        #expect(slices.allSatisfy { $0.width == 200 })

        let scaled = try Slicer.render(try Slicer.loadImage(at: source), plan: output.plan)
        #expect(stack(slices, space: space) == bytes(of: scaled, space: space))
    }

    @Test func eachRowAppearsExactlyOnceAcrossSeams() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let source = try writeRowCodedPNG(name: "rows", width: 4, height: 1000, space: space)

        let output = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 100)
        let stacked = stack(try output.files.map(readImage), space: space)

        // Decode the row index from the first pixel of each row: it must count 0, 1, 2, … with no skips or repeats.
        let rowBytes = 4 * 4
        let rows = stride(from: 0, to: stacked.count, by: rowBytes).map { Int(stacked[$0]) | Int(stacked[$0 + 1]) << 8 }
        #expect(rows == Array(0..<1000))
    }

    // MARK: Output naming

    @Test func writesNumberedFilesIntoFolderNextToSource() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let source = try writeRowCodedPNG(name: "shot", width: 10, height: 250, space: space)

        let output = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 100)

        #expect(output.folder.standardizedFileURL.path() == dir.appending(path: "shot slices/").standardizedFileURL.path())
        #expect(output.files.map(\.lastPathComponent) == ["shot-01.png", "shot-02.png", "shot-03.png"])
    }

    @Test func neverOverwritesAnExistingFolder() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let source = try writeRowCodedPNG(name: "shot", width: 10, height: 250, space: space)

        _ = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 100)
        let second = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 100)
        let third = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 100)

        #expect(second.folder.lastPathComponent == "shot slices 2")
        #expect(third.folder.lastPathComponent == "shot slices 3")
    }

    @Test func padsNumbersToFitSliceCount() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let source = try writeRowCodedPNG(name: "long", width: 2, height: 120, space: space)

        let output = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 1)

        #expect(output.files.first?.lastPathComponent == "long-001.png")
        #expect(output.files.last?.lastPathComponent == "long-120.png")
    }

    @Test func jpegInputProducesPNGSlices() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let image = rowCodedImage(width: 50, height: 300, space: space)
        let source = dir.appending(path: "photo.jpg")
        try write(image, to: source, type: .jpeg)

        let output = try Slicer.slice(source, maxWidth: 4096, sliceHeight: 100)

        #expect(output.files.map(\.pathExtension) == ["png", "png", "png"])
        #expect(try output.files.map { try uti(of: $0) } == [UTType.png.identifier, UTType.png.identifier, UTType.png.identifier])
    }

    @Test func recognizesImages() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let png = try writeRowCodedPNG(name: "a", width: 1, height: 1, space: space)
        let text = dir.appending(path: "notes.txt")
        try "hi".write(to: text, atomically: true, encoding: .utf8)

        #expect(Slicer.isImage(png))
        #expect(!Slicer.isImage(text))
        #expect(throws: Slicer.Failure.self) { try Slicer.slice(text, maxWidth: 4096, sliceHeight: 100) }
    }

    // MARK: Helpers

    /// Every row gets a unique color (row index in R and G), columns vary in B.
    private func rowCodedImage(width: Int, height: Int, space: CGColorSpace) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                pixels[i] = UInt8(y & 0xFF)
                pixels[i + 1] = UInt8((y >> 8) & 0xFF)
                pixels[i + 2] = UInt8((x * 37) & 0xFF)
            }
        }
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    private func writeRowCodedPNG(name: String, width: Int, height: Int, space: CGColorSpace) throws -> URL {
        let url = dir.appending(path: "\(name).png")
        try write(rowCodedImage(width: width, height: height, space: space), to: url, type: .png)
        return url
    }

    private func write(_ image: CGImage, to url: URL, type: UTType) throws {
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }

    private func readImage(_ url: URL) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func uti(of url: URL) throws -> String? {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return CGImageSourceGetType(source) as String?
    }

    /// Raw RGBA8 bytes, rendered in the same color space so no conversion happens.
    private func bytes(of image: CGImage, space: CGColorSpace) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &out, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return out
    }

    private func stack(_ slices: [CGImage], space: CGColorSpace) -> [UInt8] {
        slices.flatMap { bytes(of: $0, space: space) }
    }
}
