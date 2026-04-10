import AppKit

/// 전체 화면 녹화 시 화면 좌측 상단에 "● REC" 배지를 표시한다.
/// 창은 ignoresMouseEvents=true로 클릭이 통과하며, 녹화 영역 밖(메뉴바 높이)에 위치.
@MainActor
class FullScreenRecordingIndicator {
    private var window: NSWindow?
    private var blinkTimer: Timer?
    private var isPulsed = false

    func show() {
        let badgeW: CGFloat = 70
        let badgeH: CGFloat = 24
        // 메뉴바 높이 아래, 좌측 상단에 배치
        let menuBarHeight = NSApp.mainMenu?.menuBarHeight ?? 25
        let x: CGFloat = 8
        let screenHeight = NSScreen.main?.frame.height ?? 900
        // NSWindow frame은 bottom-left origin이므로 y 변환
        let y = screenHeight - menuBarHeight - badgeH - 4

        let w = NSWindow(
            contentRect: NSRect(x: x, y: y, width: badgeW, height: badgeH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.ignoresMouseEvents = true
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = RecBadgeView(frame: NSRect(x: 0, y: 0, width: badgeW, height: badgeH))
        w.contentView = view
        w.orderFrontRegardless()

        self.window = w

        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPulsed.toggle()
                self.window?.alphaValue = self.isPulsed ? 0.3 : 1.0
            }
        }
    }

    func hide() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Badge view

private class RecBadgeView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()

        let text = NSAttributedString(
            string: "● REC",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        let textSize = text.size()
        let textOrigin = NSPoint(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2
        )
        text.draw(at: textOrigin)
    }
}
