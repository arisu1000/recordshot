import AppKit

/// Displays a pulsing red dashed border around the active recording region.
/// The border is drawn *outside* the captured sourceRect so it never appears
/// in the recorded video/GIF.
@MainActor
class RecordingRegionIndicator {
    private var window: NSWindow?
    private var borderView: RegionBorderView?
    private var blinkTimer: Timer?
    private var isPulsed = false

    func show(region: CGRect) {
        guard let screenFrame = NSScreen.main?.frame else { return }

        let w = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.ignoresMouseEvents = true
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = RegionBorderView(frame: screenFrame)
        view.region = region
        w.contentView = view
        w.orderFrontRegardless()

        self.window = w
        self.borderView = view

        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPulsed.toggle()
                self.borderView?.alpha = self.isPulsed ? 0.3 : 1.0
            }
        }
    }

    func hide() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        window?.orderOut(nil)
        window = nil
        borderView = nil
    }
}

// MARK: - Border view

private class RegionBorderView: NSView {
    var region: CGRect = .zero
    var alpha: CGFloat = 1.0 { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }
    // region comes from RegionSelector which returns top-left origin coordinates
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Fully transparent — lets the display content show through (recording area unaffected)
        NSColor.clear.setFill()
        bounds.fill()

        guard region.width > 4 else { return }

        // 3 px OUTSIDE the sourceRect — never captured by SCStream
        let borderRect = region.insetBy(dx: -3, dy: -3)
        let color = NSColor.systemRed.withAlphaComponent(alpha)

        // Dashed red border
        let path = NSBezierPath(rect: borderRect)
        path.lineWidth = 3
        path.setLineDash([10, 5], count: 2, phase: 0)
        color.setStroke()
        path.stroke()

        // "● REC" badge positioned ABOVE the top edge (outside recording area)
        let recText = NSAttributedString(
            string: " ● REC ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(alpha)
            ]
        )
        let textSize = recText.size()
        let badgeH = textSize.height + 6
        let badgeW = textSize.width + 4
        // In flipped view (top-left origin): minY is the top edge.
        // Badge goes above the top edge → y = minY - badgeH - 2
        let badgeRect = NSRect(
            x: borderRect.minX,
            y: borderRect.minY - badgeH - 2,
            width: badgeW,
            height: badgeH
        )
        NSColor.systemRed.withAlphaComponent(alpha * 0.9).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3).fill()
        recText.draw(at: NSPoint(x: badgeRect.minX + 2, y: badgeRect.minY + 3))
    }
}
