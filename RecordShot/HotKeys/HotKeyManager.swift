import AppKit
import Carbon

class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let settings = AppSettings.shared

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard AXIsProcessTrusted() else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return manager.handleKeyEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let cmdShift = CGEventFlags([.maskCommand, .maskShift])

        // ⌘⇧3 — Full screenshot
        if flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]) == cmdShift && keyCode == 20 {
            Task { @MainActor in
                await ScreenCaptureManager.shared.takeFullScreenshot()
            }
            return nil
        }

        // ⌘⇧4 — Region screenshot
        if flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]) == cmdShift && keyCode == 21 {
            Task { @MainActor in
                await ScreenCaptureManager.shared.takeRegionScreenshot()
            }
            return nil
        }

        // ⌘⇧5 — Toggle recording
        if flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]) == cmdShift && keyCode == 23 {
            Task { @MainActor in
                let manager = ScreenCaptureManager.shared
                if manager.isRecording {
                    await manager.stopRecording()
                } else {
                    await manager.startRecording()
                }
            }
            return nil
        }

        // ⌘⇧6 — Region recording
        if flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]) == cmdShift && keyCode == 22 {
            Task { @MainActor in
                let manager = ScreenCaptureManager.shared
                if !manager.isRecording {
                    await manager.startRegionRecording()
                }
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
