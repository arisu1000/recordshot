import AppKit
import SwiftUI

@MainActor
class ImageEditorWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    var onDismiss: (() -> Void)?

    func open(image: NSImage, originalCGImage: CGImage, onComplete: @escaping (CGImage) -> Void) {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let chrome: CGFloat = 56 + 52  // toolbar + action bar

        // 이미지 원본 크기에 맞추되, 화면의 90%를 초과하면 제한
        let maxW = screen.width * 0.9
        let maxH = screen.height * 0.9 - chrome
        let contentW = min(image.size.width, maxW)
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
        w.title = NSLocalizedString("editor.title", comment: "")
        w.minSize = NSSize(width: 400, height: 300)
        w.delegate = self

        w.contentView = NSHostingView(
            rootView: ImageEditorView(
                baseImage: image,
                baseCGImage: originalCGImage,
                onComplete: { [weak self] cgResult in
                    onComplete(cgResult)
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
        guard let w = window else { return }
        window = nil
        let dismiss = onDismiss
        onDismiss = nil
        w.delegate = nil
        w.orderOut(nil)     // 창을 숨김 (close와 달리 뷰 계층을 즉시 파괴하지 않음)
        dismiss?()          // editorWindows에서 제거 → self 해제 가능
        // w는 로컬 변수로 이 메서드 끝까지 유지됨
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // X 버튼을 Cancel과 동일한 코드 경로로 처리
        // windowWillClose에서 처리하면 NSHostingView 해제 시점과 충돌해 크래시 발생
        // false를 반환해 시스템이 직접 닫지 않도록 하고, close()가 orderOut으로 처리
        DispatchQueue.main.async { [weak self] in self?.close() }
        return false
    }
}
