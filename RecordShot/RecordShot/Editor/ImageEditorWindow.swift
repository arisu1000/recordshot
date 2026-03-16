import AppKit
import SwiftUI

@MainActor
class ImageEditorWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func open(image: NSImage, onComplete: @escaping (NSImage) -> Void) {
        close()

        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let chrome: CGFloat = 56 + 52  // toolbar + action bar

        let maxW = screen.width * 0.9
        let maxH = (screen.height - chrome) * 0.9
        let scale = min(1.0, min(maxW / image.size.width, maxH / image.size.height))
        let contentW = max(image.size.width * scale, 520)
        let contentH = image.size.height * scale + chrome

        let rect = NSRect(
            x: screen.midX - contentW / 2,
            y: screen.midY - contentH / 2,
            width: contentW,
            height: contentH
        )

        let w = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "이미지 편집"
        w.minSize = NSSize(width: 520, height: 400)
        w.delegate = self

        w.contentView = NSHostingView(
            rootView: ImageEditorView(
                baseImage: image,
                onComplete: { [weak self] edited in
                    onComplete(edited)
                    DispatchQueue.main.async { self?.close() }
                },
                onCancel: { [weak self] in
                    DispatchQueue.main.async { self?.close() }
                }
            )
        )

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
