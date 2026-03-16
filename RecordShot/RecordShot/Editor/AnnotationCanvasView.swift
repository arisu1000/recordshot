import AppKit
import CoreImage

// MARK: - NSView canvas (isFlipped = true → top-left origin)

class AnnotationCanvasNSView: NSView {
    var baseImage: NSImage? { didSet { invalidateIntrinsicContentSize() } }
    var annotations: [Annotation] = []
    var currentAnnotation: Annotation?

    var currentTool: AnnotationTool = .rectangle
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 3
    var currentFontSize: CGFloat = 18
    var displayScale: CGFloat = 1.0

    var onAnnotationCommitted: ((Annotation) -> Void)?

    private var activeTextField: NSTextField?
    private var pendingTextAnnotationId: UUID?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { baseImage?.size ?? super.intrinsicContentSize }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()

        // Base image — flipped 뷰에서 올바른 방향으로 그리기
        if let img = baseImage {
            img.draw(in: bounds,
                     from: NSRect(origin: .zero, size: img.size),
                     operation: .sourceOver,
                     fraction: 1.0,
                     respectFlipped: true,
                     hints: nil)
        }

        // Committed annotations
        for ann in annotations {
            drawAnnotation(ann)
        }

        // In-progress annotation
        if let current = currentAnnotation {
            drawAnnotation(current)
        }

        ctx.restoreGState()
    }

    private func drawAnnotation(_ ann: Annotation) {
        switch ann.tool {
        case .rectangle:
            let path = NSBezierPath(rect: ann.rect)
            path.lineWidth = ann.lineWidth
            ann.color.setStroke()
            path.stroke()

        case .circle:
            let path = NSBezierPath(ovalIn: ann.rect)
            path.lineWidth = ann.lineWidth
            ann.color.setStroke()
            path.stroke()

        case .arrow:
            drawArrow(from: ann.startPoint, to: ann.endPoint, color: ann.color, lineWidth: ann.lineWidth)

        case .text:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: ann.fontSize, weight: .bold),
                .foregroundColor: ann.color
            ]
            NSAttributedString(string: ann.text, attributes: attrs).draw(at: ann.startPoint)

        case .blur:
            NSColor.black.withAlphaComponent(0.45).setFill()
            NSBezierPath(rect: ann.rect).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            let label = NSAttributedString(string: NSLocalizedString("editor.blurLabel", comment: ""), attributes: attrs)
            let sz = label.size()
            label.draw(at: NSPoint(x: ann.rect.midX - sz.width / 2, y: ann.rect.midY - sz.height / 2))
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        color.setFill()

        let line = NSBezierPath()
        line.lineWidth = lineWidth
        line.lineCapStyle = .round
        line.move(to: start)
        line.line(to: end)
        line.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLen: CGFloat = max(16, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: CGPoint(x: end.x - arrowLen * cos(angle - arrowAngle),
                              y: end.y - arrowLen * sin(angle - arrowAngle)))
        head.line(to: CGPoint(x: end.x - arrowLen * cos(angle + arrowAngle),
                              y: end.y - arrowLen * sin(angle + arrowAngle)))
        head.close()
        head.fill()
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        // Commit any in-flight text field
        if let tf = activeTextField {
            window?.makeFirstResponder(self)
            _ = tf  // textFieldDidEndEditing handles cleanup
        }

        if currentTool == .text {
            var ann = Annotation(tool: .text)
            ann.startPoint = pt
            ann.endPoint = pt
            ann.color = currentColor
            ann.fontSize = currentFontSize
            ann.text = ""
            annotations.append(ann)
            showTextField(for: ann)
            return
        }

        var ann = Annotation(tool: currentTool)
        ann.startPoint = pt
        ann.endPoint = pt
        ann.color = currentColor
        ann.lineWidth = currentLineWidth
        ann.fontSize = currentFontSize
        currentAnnotation = ann
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentAnnotation?.endPoint = pt
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        guard var ann = currentAnnotation else { return }
        ann.endPoint = pt
        currentAnnotation = nil

        if ann.isValid {
            annotations.append(ann)
            onAnnotationCommitted?(ann)
        }
        needsDisplay = true
    }

    // MARK: - Text field overlay

    private func showTextField(for ann: Annotation) {
        activeTextField?.removeFromSuperview()
        pendingTextAnnotationId = ann.id

        let tf = NSTextField(frame: NSRect(x: ann.startPoint.x,
                                           y: ann.startPoint.y,
                                           width: 220,
                                           height: ann.fontSize + 10))
        tf.isEditable = true
        tf.isBezeled = false
        tf.drawsBackground = true
        tf.backgroundColor = NSColor.white.withAlphaComponent(0.15)
        tf.textColor = ann.color
        tf.font = NSFont.systemFont(ofSize: ann.fontSize, weight: .bold)
        tf.placeholderString = NSLocalizedString("editor.textPlaceholder", comment: "")
        tf.focusRingType = .none
        tf.target = self
        tf.action = #selector(textFieldAction(_:))

        addSubview(tf)
        window?.makeFirstResponder(tf)
        activeTextField = tf

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textFieldDidEndEditing(_:)),
            name: NSControl.textDidEndEditingNotification,
            object: tf
        )
    }

    @objc private func textFieldAction(_ sender: NSTextField) {
        commitTextField(sender)
    }

    @objc private func textFieldDidEndEditing(_ notification: Notification) {
        guard let tf = notification.object as? NSTextField else { return }
        commitTextField(tf)
    }

    private func commitTextField(_ tf: NSTextField) {
        guard let id = pendingTextAnnotationId else { return }

        let text = tf.stringValue.trimmingCharacters(in: .whitespaces)
        if let idx = annotations.firstIndex(where: { $0.id == id }) {
            if text.isEmpty {
                annotations.remove(at: idx)
            } else {
                annotations[idx].text = text
            }
        }

        NotificationCenter.default.removeObserver(self, name: NSControl.textDidEndEditingNotification, object: tf)
        tf.removeFromSuperview()
        activeTextField = nil
        pendingTextAnnotationId = nil
        needsDisplay = true
    }

    // MARK: - Undo

    func undoLast() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        needsDisplay = true
    }

    // MARK: - Export

    func renderToFinalImage() -> NSImage {
        guard let baseImage = baseImage else { return NSImage() }

        // Commit any in-flight annotation
        if let tf = activeTextField { commitTextField(tf) }

        // No annotations → return original image untouched (zero quality loss)
        if annotations.isEmpty { return baseImage }

        let origSize = baseImage.size           // logical size (points)
        let scaleUp = origSize.width / bounds.width  // view → logical

        // Get the base CGImage to work in full pixel resolution
        guard let cgBase = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return baseImage
        }
        let pixelW = cgBase.width
        let pixelH = cgBase.height
        let pixelScale = CGFloat(pixelW) / origSize.width   // points → pixels

        // Step 1: Apply blur via CIFilter in pixel space
        var workingCGImage = cgBase
        let blurAnns = annotations.filter { $0.tool == .blur }
        if !blurAnns.isEmpty {
            var ciImg = CIImage(cgImage: cgBase)
            let ciContext = CIContext()
            let viewToPixel = scaleUp * pixelScale  // view coords → pixel coords

            for ann in blurAnns {
                let pixelRect = CGRect(
                    x: ann.rect.origin.x * viewToPixel,
                    y: ann.rect.origin.y * viewToPixel,
                    width: ann.rect.width  * viewToPixel,
                    height: ann.rect.height * viewToPixel
                )
                let ciRect = CGRect(
                    x: pixelRect.origin.x,
                    y: CGFloat(pixelH) - pixelRect.origin.y - pixelRect.height,
                    width: pixelRect.width,
                    height: pixelRect.height
                )
                let blurred = ciImg
                    .cropped(to: ciRect)
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 14.0 * pixelScale])
                    .cropped(to: ciRect)
                ciImg = blurred.composited(over: ciImg)
            }

            if let result = ciContext.createCGImage(ciImg, from: ciImg.extent) {
                workingCGImage = result
            }
        }

        // Step 2: Render non-blur annotations at full pixel resolution.
        // Use a raw CGContext scaled by pixelScale so all drawing uses point coordinates —
        // identical coordinate space to the view, but producing pixelW × pixelH output pixels.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgCtx = CGContext(
            data: nil,
            width: pixelW, height: pixelH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return baseImage }

        cgCtx.scaleBy(x: pixelScale, y: pixelScale)  // pixel → point coordinate space

        let gc = NSGraphicsContext(cgContext: cgCtx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc

        // Draw base image at logical (point) size — context scale handles Retina pixels
        NSImage(cgImage: workingCGImage, size: origSize)
            .draw(in: CGRect(origin: .zero, size: origSize))

        // Transform: view coords (top-left) → point coords (bottom-left) with Y flip
        let xform = NSAffineTransform()
        xform.translateX(by: 0, yBy: origSize.height)
        xform.scaleX(by: scaleUp, yBy: -scaleUp)
        xform.concat()

        for ann in annotations where ann.tool != .blur {
            drawAnnotationForExport(ann)
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let resultCG = cgCtx.makeImage() else { return baseImage }
        return NSImage(cgImage: resultCG, size: origSize)
    }

    private func drawAnnotationForExport(_ ann: Annotation) {
        switch ann.tool {
        case .rectangle:
            let path = NSBezierPath(rect: ann.rect)
            path.lineWidth = ann.lineWidth
            ann.color.setStroke()
            path.stroke()

        case .circle:
            let path = NSBezierPath(ovalIn: ann.rect)
            path.lineWidth = ann.lineWidth
            ann.color.setStroke()
            path.stroke()

        case .arrow:
            drawArrow(from: ann.startPoint, to: ann.endPoint, color: ann.color, lineWidth: ann.lineWidth)

        case .text:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: ann.fontSize, weight: .bold),
                .foregroundColor: ann.color
            ]
            NSAttributedString(string: ann.text, attributes: attrs).draw(at: ann.startPoint)

        case .blur:
            break
        }
    }
}

// MARK: - SwiftUI representable (NSScrollView 기반)

import SwiftUI

struct AnnotationCanvasView: NSViewRepresentable {
    let baseImage: NSImage
    let currentTool: AnnotationTool
    let currentColor: NSColor
    let lineWidth: CGFloat
    let fontSize: CGFloat
    let onReady: (AnnotationCanvasNSView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let canvasView = AnnotationCanvasNSView()
        canvasView.baseImage = baseImage
        canvasView.displayScale = 1.0
        canvasView.autoresizingMask = []  // 스크롤뷰에 의한 리사이즈 방지
        canvasView.frame = NSRect(origin: .zero, size: baseImage.size)

        let scrollView = NSScrollView()
        scrollView.documentView = canvasView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .underPageBackgroundColor
        scrollView.drawsBackground = true
        scrollView.allowsMagnification = false

        onReady(canvasView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let v = scrollView.documentView as? AnnotationCanvasNSView else { return }
        v.currentTool = currentTool
        v.currentColor = currentColor
        v.currentLineWidth = lineWidth
        v.currentFontSize = fontSize
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject {}
}
