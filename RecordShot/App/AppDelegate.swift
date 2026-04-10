import AppKit
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var hotKeyManager: HotKeyManager?
    var onboardingWindow: OnboardingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock - LSUIElement handles this, but ensure it
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
        hotKeyManager = HotKeyManager()

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            onboardingWindow = OnboardingWindow()
            onboardingWindow?.show()
        }

        // Request screen capture permission, then execute launch action
        Task {
            await requestScreenCapturePermission()
            await executeLaunchAction()
        }
    }

    private func executeLaunchAction() async {
        let action = LaunchAction(rawValue: AppSettings.shared.launchAction) ?? .none
        guard action != .none else { return }

        // 앱 초기화 완료 후 약간의 지연 — UI가 준비되도록 보장
        try? await Task.sleep(nanoseconds: 300_000_000)

        let manager = ScreenCaptureManager.shared
        switch action {
        case .none: break
        case .fullScreenshot: await manager.takeFullScreenshot()
        case .regionScreenshot: await manager.takeRegionScreenshot()
        case .fullRecording: await manager.startRecording()
        case .regionRecording: await manager.startRegionRecording()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.stopMonitoring()
    }

    private func requestScreenCapturePermission() async {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            // Permission not granted - will be requested when user tries to capture
        }
    }
}
