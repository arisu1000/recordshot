import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var savePath: String {
        didSet { UserDefaults.standard.set(savePath, forKey: "savePath") }
    }
    @Published var autoCopyToClipboard: Bool {
        didSet { UserDefaults.standard.set(autoCopyToClipboard, forKey: "autoCopyToClipboard") }
    }
    @Published var maxRecordingDuration: Int {
        didSet { UserDefaults.standard.set(maxRecordingDuration, forKey: "maxRecordingDuration") }
    }
    @Published var screenshotShortcut: String {
        didSet { UserDefaults.standard.set(screenshotShortcut, forKey: "screenshotShortcut") }
    }
    @Published var recordingShortcut: String {
        didSet { UserDefaults.standard.set(recordingShortcut, forKey: "recordingShortcut") }
    }

    private init() {
        let defaults = UserDefaults.standard

        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop").path

        savePath = defaults.string(forKey: "savePath") ?? defaultPath
        autoCopyToClipboard = defaults.object(forKey: "autoCopyToClipboard") as? Bool ?? true
        maxRecordingDuration = defaults.object(forKey: "maxRecordingDuration") as? Int ?? 0
        screenshotShortcut = defaults.string(forKey: "screenshotShortcut") ?? "⌘⇧3"
        recordingShortcut = defaults.string(forKey: "recordingShortcut") ?? "⌘⇧5"
    }
}
