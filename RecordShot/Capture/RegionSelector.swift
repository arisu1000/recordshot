import AppKit
import Foundation

@MainActor
class RegionSelector {
    // static으로 보관해서 ARC 해제 방지
    private static var current: RegionSelectorWindow?

    static func selectRegion() async -> CGRect? {
        await withCheckedContinuation { continuation in
            let selector = RegionSelectorWindow()
            current = selector
            selector.onRegionSelected = { region in
                current = nil
                continuation.resume(returning: region)
            }
            selector.onCancelled = {
                current = nil
                continuation.resume(returning: nil)
            }
            selector.showWindow()
        }
    }
}

class RegionSelectorWindow: NSObject {
    var onRegionSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var window: NSWindow?
    private var overlayView: RegionOverlayView?

    func showWindow() {
        let screenRect = NSScreen.main?.frame ?? .zero

        window = NSWindow(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.ignoresMouseEvents = false
        window?.acceptsMouseMovedEvents = true
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlay = RegionOverlayView(frame: screenRect)
        overlay.onRegionSelected = { [weak self] region in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.onRegionSelected?(region)
        }
        overlay.onCancelled = { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.onCancelled?()
        }

        overlayView = overlay
        window?.contentView = overlay
        window?.makeKeyAndOrderFront(nil)

        // Change cursor to crosshair
        NSCursor.crosshair.push()
    }
}

class RegionOverlayView: NSView {
    var onRegionSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var sizeLabel: NSTextField?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupSizeLabel()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupSizeLabel() {
        let label = NSTextField(labelWithString: "")
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        label.textColor = .white
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.isBezeled = false
        label.drawsBackground = true
        label.isHidden = true
        addSubview(label)
        sizeLabel = label
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dark overlay
        NSColor.black.withAlphaComponent(0.4).setFill()
        dirtyRect.fill()

        if let rect = currentRect {
            // Clear the selected region (punch-out effect)
            NSGraphicsContext.current?.compositingOperation = .clear
            rect.fill()

            // Draw border around selected region
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.white.withAlphaComponent(0.8).setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 2
            border.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        currentRect = rect

        // Update size label
        let width = Int(rect.width)
        let height = Int(rect.height)
        sizeLabel?.stringValue = " \(width) × \(height) "
        sizeLabel?.sizeToFit()
        sizeLabel?.frame.origin = NSPoint(
            x: min(current.x + 10, frame.width - (sizeLabel?.frame.width ?? 0) - 10),
            y: max(current.y - 30, 10)
        )
        sizeLabel?.isHidden = width < 10 || height < 10

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width > 10, rect.height > 10 else {
            onCancelled?()
            return
        }

        NSCursor.pop()

        // Convert to screen coordinates (flip Y for macOS coordinate system)
        let screenHeight = frame.height
        let screenRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        onRegionSelected?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            NSCursor.pop()
            onCancelled?()
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
