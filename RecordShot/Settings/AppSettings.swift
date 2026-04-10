import Foundation
import Combine

enum LaunchAction: String, CaseIterable, Identifiable {
    case none
    case fullScreenshot
    case regionScreenshot
    case fullRecording
    case regionRecording

    var id: Self { self }

    var displayName: String {
        switch self {
        case .none: return NSLocalizedString("settings.launchAction.none", comment: "")
        case .fullScreenshot: return NSLocalizedString("settings.launchAction.fullScreenshot", comment: "")
        case .regionScreenshot: return NSLocalizedString("settings.launchAction.regionScreenshot", comment: "")
        case .fullRecording: return NSLocalizedString("settings.launchAction.fullRecording", comment: "")
        case .regionRecording: return NSLocalizedString("settings.launchAction.regionRecording", comment: "")
        }
    }
}

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
    @Published var recordingFormat: String {
        didSet { UserDefaults.standard.set(recordingFormat, forKey: "recordingFormat") }
    }
    @Published var recordingSavePath: String {
        didSet { UserDefaults.standard.set(recordingSavePath, forKey: "recordingSavePath") }
    }
    @Published var launchAction: String {
        didSet { UserDefaults.standard.set(launchAction, forKey: "launchAction") }
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
        recordingFormat = defaults.string(forKey: "recordingFormat") ?? RecordingFormat.mp4.rawValue
        recordingSavePath = defaults.string(forKey: "recordingSavePath") ?? defaultPath
        launchAction = defaults.string(forKey: "launchAction") ?? LaunchAction.none.rawValue
    }
}
