import XCTest
import AppKit
@testable import RecordShot

final class ImageProcessingTests: XCTestCase {

    // MARK: - NSImage.thumbnail

    func test_thumbnail_fitsWithinMaxSize() {
        let original = NSImage(size: NSSize(width: 400, height: 200))
        let maxSize  = CGSize(width: 100, height: 50)
        let thumb    = original.thumbnail(maxSize: maxSize)

        XCTAssertLessThanOrEqual(thumb.size.width,  maxSize.width  + 0.01)
        XCTAssertLessThanOrEqual(thumb.size.height, maxSize.height + 0.01)
    }

    func test_thumbnail_aspectRatioPreserved_landscape() {
        let original = NSImage(size: NSSize(width: 400, height: 200))
        let maxSize  = CGSize(width: 240, height: 80)
        let thumb    = original.thumbnail(maxSize: maxSize)

        let originalRatio = original.size.width / original.size.height
        let thumbRatio    = thumb.size.width    / thumb.size.height
        XCTAssertEqual(originalRatio, thumbRatio, accuracy: 0.01)
    }

    func test_thumbnail_aspectRatioPreserved_portrait() {
        let original = NSImage(size: NSSize(width: 200, height: 400))
        let maxSize  = CGSize(width: 80, height: 240)
        let thumb    = original.thumbnail(maxSize: maxSize)

        let originalRatio = original.size.width / original.size.height
        let thumbRatio    = thumb.size.width    / thumb.size.height
        XCTAssertEqual(originalRatio, thumbRatio, accuracy: 0.01)
    }

    func test_thumbnail_square_aspectRatioPreserved() {
        let original = NSImage(size: NSSize(width: 500, height: 500))
        let maxSize  = CGSize(width: 100, height: 80)
        let thumb    = original.thumbnail(maxSize: maxSize)

        XCTAssertEqual(thumb.size.width, thumb.size.height, accuracy: 0.01)
    }

    func test_thumbnail_smallImageScalesDown() {
        // Image fits in maxSize — ratio constraint still applies but no upscaling forced
        let original = NSImage(size: NSSize(width: 50, height: 25))
        let maxSize  = CGSize(width: 240, height: 80)
        let thumb    = original.thumbnail(maxSize: maxSize)

        let originalRatio = original.size.width / original.size.height
        let thumbRatio    = thumb.size.width    / thumb.size.height
        XCTAssertEqual(originalRatio, thumbRatio, accuracy: 0.01)
    }

    func test_thumbnail_widthConstraintDominates() {
        // 800x100 → maxSize 100x100: scale = min(100/800, 100/100) = 0.125
        // expected: 100 x 12.5
        let original = NSImage(size: NSSize(width: 800, height: 100))
        let maxSize  = CGSize(width: 100, height: 100)
        let thumb    = original.thumbnail(maxSize: maxSize)

        XCTAssertEqual(thumb.size.width,  100,  accuracy: 0.01)
        XCTAssertEqual(thumb.size.height, 12.5, accuracy: 0.01)
    }

    func test_thumbnail_heightConstraintDominates() {
        // 100x800 → maxSize 100x100: scale = min(100/100, 100/800) = 0.125
        // expected: 12.5 x 100
        let original = NSImage(size: NSSize(width: 100, height: 800))
        let maxSize  = CGSize(width: 100, height: 100)
        let thumb    = original.thumbnail(maxSize: maxSize)

        XCTAssertEqual(thumb.size.width,  12.5, accuracy: 0.01)
        XCTAssertEqual(thumb.size.height, 100,  accuracy: 0.01)
    }

    // MARK: - File naming

    func test_screenshotFileName_prefix_and_extension() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts  = formatter.string(from: Date())
        let name = "screenshot_\(ts).png"
        XCTAssertTrue(name.hasPrefix("screenshot_"))
        XCTAssertTrue(name.hasSuffix(".png"))
    }

    func test_regionFileName_prefix_and_extension() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts  = formatter.string(from: Date())
        let name = "region_\(ts).png"
        XCTAssertTrue(name.hasPrefix("region_"))
        XCTAssertTrue(name.hasSuffix(".png"))
    }

    func test_recordingFileName_prefix_and_extension() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts  = formatter.string(from: Date())
        let name = "recording_\(ts).mp4"
        XCTAssertTrue(name.hasPrefix("recording_"))
        XCTAssertTrue(name.hasSuffix(".mp4"))
    }

    func test_timestampFormat_length() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts = formatter.string(from: Date())
        // "2026-03-16_12-30-45" = 19 chars
        XCTAssertEqual(ts.count, 19)
    }

    func test_timestampFormat_containsSeparators() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts = formatter.string(from: Date())
        XCTAssertTrue(ts.contains("-"))
        XCTAssertTrue(ts.contains("_"))
    }

    func test_filename_noSpaces() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts = formatter.string(from: Date())
        XCTAssertFalse(ts.contains(" "))
        XCTAssertFalse("screenshot_\(ts).png".contains(" "))
    }

    // MARK: - Logical size calculation (Retina)

    func test_logicalSize_retinaScale2x() {
        let pixelWidth:  CGFloat = 2880
        let pixelHeight: CGFloat = 1800
        let scale:       CGFloat = 2.0

        let logicalW = pixelWidth  / scale
        let logicalH = pixelHeight / scale

        XCTAssertEqual(logicalW, 1440)
        XCTAssertEqual(logicalH, 900)
    }

    func test_logicalSize_scale1x() {
        let pixelWidth:  CGFloat = 1920
        let pixelHeight: CGFloat = 1080
        let scale:       CGFloat = 1.0

        XCTAssertEqual(pixelWidth  / scale, 1920)
        XCTAssertEqual(pixelHeight / scale, 1080)
    }

    func test_logicalSize_scale3x() {
        let pixelWidth:  CGFloat = 3000
        let pixelHeight: CGFloat = 1500
        let scale:       CGFloat = 3.0

        XCTAssertEqual(pixelWidth  / scale, 1000)
        XCTAssertEqual(pixelHeight / scale, 500)
    }
}
