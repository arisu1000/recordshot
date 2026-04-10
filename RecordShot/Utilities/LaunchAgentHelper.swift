import Foundation

/// ~/Library/LaunchAgents에 plist를 생성/삭제하여 로그인 시 자동 실행을 관리한다.
/// SMAppService와 달리 ad-hoc 서명에서도 동작한다.
enum LaunchAgentHelper {
    private static let label = "com.recordshot.app"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func enable() {
        let executablePath: String
        if let bundlePath = Bundle.main.bundlePath as String?,
           bundlePath.hasSuffix(".app") {
            executablePath = bundlePath
        } else {
            executablePath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
        }

        // open 명령어로 .app 번들을 실행 — 직접 바이너리 실행보다 안정적
        let plistContent: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", executablePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        do {
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
            try data.write(to: plistURL)
            Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load", plistURL.path])
        } catch {
            print("[RecordShot] Failed to enable launch at login: \(error)")
        }
    }

    static func disable() {
        do {
            Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload", plistURL.path])
            try FileManager.default.removeItem(at: plistURL)
        } catch {
            print("[RecordShot] Failed to disable launch at login: \(error)")
        }
    }
}
