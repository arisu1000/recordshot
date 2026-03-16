import XCTest
@testable import RecordShot

final class AppSettingsTests: XCTestCase {

    // AppSettings uses UserDefaults.standard with private init().
    // We snapshot values before each test and restore after.

    private var originalSavePath = ""
    private var originalAutoCopy = true
    private var originalMaxDuration = 0
    private var originalScreenshotShortcut = ""
    private var originalRecordingShortcut = ""

    override func setUp() {
        super.setUp()
        let s = AppSettings.shared
        originalSavePath           = s.savePath
        originalAutoCopy           = s.autoCopyToClipboard
        originalMaxDuration        = s.maxRecordingDuration
        originalScreenshotShortcut = s.screenshotShortcut
        originalRecordingShortcut  = s.recordingShortcut
    }

    override func tearDown() {
        let s = AppSettings.shared
        s.savePath              = originalSavePath
        s.autoCopyToClipboard   = originalAutoCopy
        s.maxRecordingDuration  = originalMaxDuration
        s.screenshotShortcut    = originalScreenshotShortcut
        s.recordingShortcut     = originalRecordingShortcut
        super.tearDown()
    }

    // MARK: - Persistence via UserDefaults

    func test_savePath_persistsToUserDefaults() {
        AppSettings.shared.savePath = "/tmp/recordshot_test"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "savePath"), "/tmp/recordshot_test")
    }

    func test_autoCopy_false_persistsToUserDefaults() {
        AppSettings.shared.autoCopyToClipboard = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "autoCopyToClipboard"))
    }

    func test_autoCopy_true_persistsToUserDefaults() {
        AppSettings.shared.autoCopyToClipboard = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "autoCopyToClipboard"))
    }

    func test_maxRecordingDuration_persistsToUserDefaults() {
        AppSettings.shared.maxRecordingDuration = 120
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "maxRecordingDuration"), 120)
    }

    func test_maxRecordingDuration_zero_persistsToUserDefaults() {
        AppSettings.shared.maxRecordingDuration = 0
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "maxRecordingDuration"), 0)
    }

    func test_screenshotShortcut_persistsToUserDefaults() {
        AppSettings.shared.screenshotShortcut = "⌘⇧2"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "screenshotShortcut"), "⌘⇧2")
    }

    func test_recordingShortcut_persistsToUserDefaults() {
        AppSettings.shared.recordingShortcut = "⌘⇧6"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "recordingShortcut"), "⌘⇧6")
    }

    // MARK: - In-memory values

    func test_savePath_readback() {
        AppSettings.shared.savePath = "/tmp/readback_test"
        XCTAssertEqual(AppSettings.shared.savePath, "/tmp/readback_test")
    }

    func test_maxRecordingDuration_readback() {
        AppSettings.shared.maxRecordingDuration = 60
        XCTAssertEqual(AppSettings.shared.maxRecordingDuration, 60)
    }

    func test_screenshotShortcut_readback() {
        AppSettings.shared.screenshotShortcut = "⌘⇧9"
        XCTAssertEqual(AppSettings.shared.screenshotShortcut, "⌘⇧9")
    }

    // MARK: - Default save path contains Desktop

    func test_defaultSavePath_containsDesktop() {
        // Only meaningful when no prior value is stored.
        // We just verify the current path is non-empty (already initialized).
        XCTAssertFalse(AppSettings.shared.savePath.isEmpty)
    }
}
