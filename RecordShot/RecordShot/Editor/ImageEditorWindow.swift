import AppKit
import SwiftUI

@MainActor
class ImageEditorWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    var onDismiss: (() -> Void)?

    func open(image: NSImage, onComplete: @escaping (NSImage) -> Void) {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let chrome: CGFloat = 56 + 52  // toolbar + action bar

        // 이미지 원본 크기로 창을 열되, 화면의 90%를 초과하면 그 크기로 제한
        let maxW = screen.width * 0.9
        let maxH = screen.height * 0.9 - chrome
        let contentW = max(min(image.size.width, maxW), 520)
        let contentH = min(image.size.height, maxH) + chrome

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
                    DispatchQueue.main.async {
                        self?.close()
                        self?.onDismiss?()
                    }
                },
                onCancel: { [weak self] in
                    DispatchQueue.main.async {
                        self?.close()
                        self?.onDismiss?()
                    }
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
