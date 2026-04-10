import AppKit
import SwiftUI

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var captureManager: ScreenCaptureManager!

    override init() {
        super.init()
        captureManager = ScreenCaptureManager.shared
        setupStatusItem()
        setupPopover()
        setupObservers()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon(isRecording: false)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func updateStatusItemIcon(isRecording: Bool) {
        if let button = statusItem.button {
            let iconName = isRecording ? "record.circle.fill" : "camera.fill"
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            image?.isTemplate = !isRecording
            if isRecording {
                button.contentTintColor = .systemRed
            } else {
                button.contentTintColor = nil
            }
            button.image = image
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(captureManager: captureManager, closePopover: { [weak self] in
                self?.closePopover()
            })
        )
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recordingStateChanged),
            name: .recordingStateChanged,
            object: nil
        )
    }

    @objc private func recordingStateChanged() {
        updateStatusItemIcon(isRecording: captureManager.isRecording)
    }

    @objc func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            if popover.isShown {
                closePopover()
            } else {
                openPopover()
            }
        }
    }

    func openPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.screenshot", comment: ""), action: #selector(takeScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.regionScreenshot", comment: ""), action: #selector(takeRegionScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        if captureManager.isRecording {
            menu.addItem(NSMenuItem(title: NSLocalizedString("menu.stopRecording", comment: ""), action: #selector(stopRecording), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: NSLocalizedString("menu.startRecording", comment: ""), action: #selector(startRecording), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: NSLocalizedString("menu.regionRecord", comment: ""), action: #selector(startRegionRecording), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.settingsMenu", comment: ""), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.quitApp", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func takeScreenshot() {
        Task { await captureManager.takeFullScreenshot() }
    }

    @objc private func takeRegionScreenshot() {
        Task { await captureManager.takeRegionScreenshot() }
    }

    @objc private func startRecording() {
        Task { await captureManager.startRecording() }
    }

    @objc private func startRegionRecording() {
        Task { await captureManager.startRegionRecording() }
    }

    @objc private func stopRecording() {
        Task { await captureManager.stopRecording() }
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let recordingStateChanged = Notification.Name("recordingStateChanged")
}
