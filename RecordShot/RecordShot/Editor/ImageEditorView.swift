import SwiftUI
import AppKit

struct ImageEditorView: View {
    let baseImage: NSImage
    let onComplete: (NSImage) -> Void
    let onCancel: () -> Void

    @State private var currentTool: AnnotationTool = .rectangle
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 3
    @State private var fontSize: CGFloat = 18
    @State private var canvasView: AnnotationCanvasNSView?
    @State private var hasAnnotations = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            AnnotationCanvasView(
                baseImage: baseImage,
                currentTool: currentTool,
                currentColor: NSColor(selectedColor),
                lineWidth: lineWidth,
                fontSize: fontSize,
                onReady: { view in
                    DispatchQueue.main.async { canvasView = view }
                }
            )
            .cursor(for: currentTool)

            actionBar
        }
    }

    // MARK: - Toolbar

    @ViewBuilder private var toolbar: some View {
        HStack(spacing: 6) {
            // Tool buttons
            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    currentTool = tool
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 16))
                        Text(tool.label)
                            .font(.system(size: 9))
                    }
                    .frame(width: 48, height: 40)
                    .background(currentTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(currentTool == tool ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 32)

            // Color picker
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .frame(width: 32)

            Divider().frame(height: 32)

            // Line width (hidden for text/blur)
            if currentTool != .text && currentTool != .blur {
                HStack(spacing: 4) {
                    Image(systemName: "line.horizontal.3.decrease")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $lineWidth, in: 1...12, step: 1)
                        .frame(width: 80)
                    Text("\(Int(lineWidth))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 28)
                }
            }

            // Font size (text only)
            if currentTool == .text {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $fontSize, in: 12...72, step: 2)
                        .frame(width: 80)
                    Text("\(Int(fontSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            }

            Spacer()

            // Undo
            Button {
                canvasView?.undoLast()
            } label: {
                Label(NSLocalizedString("editor.undo", comment: ""), systemImage: "arrow.uturn.backward")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        Divider()
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button(NSLocalizedString("editor.cancel", comment: "")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    guard let edited = canvasView?.renderToFinalImage() else { return }
                    let result = edited
                    DispatchQueue.main.async {
                        ClipboardManager.copyImage(result)
                        onComplete(result)
                    }
                } label: {
                    Label(NSLocalizedString("editor.copyToClipboard", comment: ""), systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    guard let edited = canvasView?.renderToFinalImage() else { return }
                    let result = edited
                    DispatchQueue.main.async {
                        onComplete(result)
                    }
                } label: {
                    Label(NSLocalizedString("editor.done", comment: ""), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

// MARK: - Cursor helper

private extension View {
    func cursor(for tool: AnnotationTool) -> some View {
        self.onAppear {
            switch tool {
            case .text: NSCursor.iBeam.set()
            default: NSCursor.crosshair.set()
            }
        }
        .onChange(of: tool) { newTool in
            switch newTool {
            case .text: NSCursor.iBeam.set()
            default: NSCursor.crosshair.set()
            }
        }
    }
}
