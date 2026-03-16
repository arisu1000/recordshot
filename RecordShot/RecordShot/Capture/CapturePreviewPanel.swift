import AppKit
import SwiftUI

@MainActor
class CapturePreviewPanel {
    private var panel: DraggablePanel?
    private let editorWindow = ImageEditorWindow()

    func show(image: NSImage, savedURL: URL, nearRegion: CGRect? = nil) {
        dismiss()

        let footerHeight: CGFloat = 40

        let imageSize: CGSize
        if nearRegion != nil {
            imageSize = image.size
        } else {
            let aspect = image.size.width / max(image.size.height, 1)
            imageSize = CGSize(width: 600, height: 600 / aspect)
        }
        let panelSize = CGSize(width: imageSize.width, height: imageSize.height + footerHeight)
        let panelRect = positionRect(size: panelSize, nearRegion: nearRegion)

        let hostingView = NSHostingView(
            rootView: CapturePreviewView(
                image: image,
                savedURL: savedURL,
                imageSize: imageSize,
                footerHeight: footerHeight,
                onCopy: { [weak self] in
                    ClipboardManager.copyImage(image)
                    self?.dismiss()
                },
                onEdit: { [weak self] in
                    guard let self = self else { return }
                    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
                    self.editorWindow.open(image: image, originalCGImage: cgImage) { cgResult in
                        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
                        let sz = NSSize(width: CGFloat(cgResult.width) / scale, height: CGFloat(cgResult.height) / scale)
                        ClipboardManager.copyImage(NSImage(cgImage: cgResult, size: sz))
                    }
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: panelSize)

        let p = DraggablePanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.backgroundColor = .windowBackgroundColor
        p.isOpaque = true
        p.hasShadow = true
        p.contentView = hostingView
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.orderFrontRegardless()
        panel = p
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func positionRect(size: CGSize, nearRegion: CGRect?) -> NSRect {
        let screen = NSScreen.main?.frame ?? .zero
        let visible = NSScreen.main?.visibleFrame ?? screen
        let margin: CGFloat = 12

        guard let region = nearRegion else {
            return NSRect(
                x: visible.maxX - size.width - margin,
                y: visible.minY + margin,
                width: size.width,
                height: size.height
            )
        }

        let regionInAppKit = NSRect(
            x: region.origin.x,
            y: screen.height - region.origin.y - region.height,
            width: region.width,
            height: region.height
        )
        var x = regionInAppKit.maxX - size.width
        var y = regionInAppKit.minY - size.height - margin
        x = max(visible.minX + margin, min(x, visible.maxX - size.width - margin))
        y = max(visible.minY + margin, min(y, visible.maxY - size.height - margin))
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

// MARK: - Draggable panel

class DraggablePanel: NSPanel {
    private var dragStart: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let current = event.locationInWindow
        setFrameOrigin(NSPoint(
            x: frame.origin.x + current.x - dragStart.x,
            y: frame.origin.y + current.y - dragStart.y
        ))
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - Preview SwiftUI view

private struct CapturePreviewView: View {
    let image: NSImage
    let savedURL: URL
    let imageSize: CGSize
    let footerHeight: CGFloat
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: imageSize.width, height: imageSize.height)
                .clipped()

            HStack(spacing: 6) {
                Text(savedURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: onEdit) {
                    Label(NSLocalizedString("preview.edit", comment: ""), systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onCopy) {
                    Label(NSLocalizedString("preview.copy", comment: ""), systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .frame(height: footerHeight)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
