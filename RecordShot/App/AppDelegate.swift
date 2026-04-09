import AppKit
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock - LSUIElement handles this, but ensure it
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
        hotKeyManager = HotKeyManager()

        // Request screen capture permission
        Task {
            await requestScreenCapturePermission()
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
