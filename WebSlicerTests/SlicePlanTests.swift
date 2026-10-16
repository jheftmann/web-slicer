import Testing
@testable import WebSlicer

struct SlicePlanTests {
    @Test func remainderBecomesShorterLastSlice() {
        let plan = SlicePlan(sourceWidth: 2880, sourceHeight: 10_000, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.slices.map(\.height) == [4096, 4096, 1808])
        #expect(plan.slices.map(\.minY) == [0, 4096, 8192])
        #expect(!plan.isScaled)
    }

    @Test func imageThatFitsIsOneSlice() {
        let plan = SlicePlan(sourceWidth: 800, sourceHeight: 600, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.slices == [PixelRect(minY: 0, width: 800, height: 600)])
    }

    @Test func exactMultipleHasNoEmptyTail() {
        let plan = SlicePlan(sourceWidth: 100, sourceHeight: 8192, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.slices.map(\.height) == [4096, 4096])
    }

    @Test func neverUpscales() {
        let plan = SlicePlan(sourceWidth: 1000, sourceHeight: 5000, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.outputWidth == 1000)
        #expect(plan.outputHeight == 5000)
        #expect(!plan.isScaled)
    }

    @Test func widthEqualToMaxIsNotScaled() {
        let plan = SlicePlan(sourceWidth: 4096, sourceHeight: 5000, maxWidth: 4096, sliceHeight: 4096)
        #expect(!plan.isScaled)
    }

    @Test func fiveKScreenshotScalesDownProportionally() {
        let plan = SlicePlan(sourceWidth: 5120, sourceHeight: 18_400, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.isScaled)
        #expect(plan.outputWidth == 4096)
        #expect(plan.outputHeight == 14_720)
        #expect(plan.slices.map(\.height) == [4096, 4096, 4096, 2432])
        #expect(plan.slices.allSatisfy { $0.width == 4096 })
    }

    @Test func scaledHeightRoundsToNearestPixel() {
        // 3000 * 4096 / 5121 = 2399.53… → 2400
        let plan = SlicePlan(sourceWidth: 5121, sourceHeight: 3000, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.outputHeight == 2400)
    }

    @Test func extremeAspectNeverScalesToZeroHeight() {
        let plan = SlicePlan(sourceWidth: 100_000, sourceHeight: 1, maxWidth: 100, sliceHeight: 100)
        #expect(plan.outputHeight == 1)
        #expect(plan.slices.count == 1)
    }

    /// Seams: every slice starts on the row the previous one ended, none overlap,
    /// none are empty, and together they cover the full output height.
    @Test(arguments: [1, 99, 100, 101, 4095, 4096, 4097, 8192, 10_000, 18_400, 50_001])
    func slicesAreContiguousAndCoverEverything(height: Int) {
        for width in [1, 1440, 2880, 4096, 5120, 7680] {
            for sliceHeight in [100, 101, 1000, 4096, 5000] {
                let plan = SlicePlan(sourceWidth: width, sourceHeight: height, maxWidth: 4096, sliceHeight: sliceHeight)
                var expectedY = 0
                for slice in plan.slices {
                    #expect(slice.minY == expectedY)
                    #expect(slice.height > 0 && slice.height <= sliceHeight)
                    #expect(slice.width == plan.outputWidth)
                    expectedY += slice.height
                }
                #expect(expectedY == plan.outputHeight)
                #expect(plan.slices.count == (plan.outputHeight + sliceHeight - 1) / sliceHeight)
            }
        }
    }

    @Test func summaryWithoutScaling() {
        let plan = SlicePlan(sourceWidth: 2880, sourceHeight: 18_400, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.summary == "2880 × 18,400 px → 5 slices")
    }

    @Test func summaryWithScaling() {
        let plan = SlicePlan(sourceWidth: 5120, sourceHeight: 18_400, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.summary == "5120 × 18,400 → 4096 × 14,720 px → 4 slices")
    }

    @Test func summarySingular() {
        let plan = SlicePlan(sourceWidth: 800, sourceHeight: 600, maxWidth: 4096, sliceHeight: 4096)
        #expect(plan.summary == "800 × 600 px → 1 slice")
    }
}

struct PixelSettingTests {
    @Test func emptyResetsToDefault() {
        #expect(PixelSetting.sanitize("") == 4096)
        #expect(PixelSetting.sanitize("   ") == 4096)
    }

    @Test func clampsToMinimum() {
        #expect(PixelSetting.sanitize("4") == 100)
        #expect(PixelSetting.sanitize("0") == 100)
    }

    @Test func acceptsLargeValues() {
        #expect(PixelSetting.sanitize("8192") == 8192)
    }

    @Test func ignoresGroupingAndNonDigits() {
        #expect(PixelSetting.sanitize("4,096") == 4096)
        #expect(PixelSetting.sanitize("2048px") == 2048)
    }

    @Test func garbageResetsToDefault() {
        #expect(PixelSetting.sanitize("abc") == 4096)
    }
}
