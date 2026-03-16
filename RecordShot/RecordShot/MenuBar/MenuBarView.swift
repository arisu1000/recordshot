import SwiftUI

struct MenuBarView: View {
    @ObservedObject var captureManager: ScreenCaptureManager
    let closePopover: () -> Void
    @State private var lastCaptureThumbnail: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.accentColor)
                Text("RecordShot")
                    .font(.headline)
                Spacer()
                if captureManager.isRecording {
                    Label(captureManager.recordingTimeString, systemImage: "record.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Action buttons
            VStack(spacing: 8) {
                // Screenshot row
                HStack(spacing: 8) {
                    ActionButton(
                        icon: "camera",
                        title: NSLocalizedString("menu.screenshot", comment: ""),
                        subtitle: "⌘⇧3"
                    ) {
                        closePopover()
                        Task { await captureManager.takeFullScreenshot() }
                    }

                    ActionButton(
                        icon: "crop",
                        title: NSLocalizedString("menu.regionScreenshot", comment: ""),
                        subtitle: "⌘⇧4"
                    ) {
                        closePopover()
                        Task { await captureManager.takeRegionScreenshot() }
                    }
                }

                // Recording button
                if captureManager.isRecording {
                    Button(action: {
                        Task { await captureManager.stopRecording() }
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                            Text(NSLocalizedString("menu.stopRecording", comment: ""))
                                .fontWeight(.medium)
                            Spacer()
                            Text(captureManager.recordingTimeString)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    ActionButton(
                        icon: "record.circle",
                        title: NSLocalizedString("menu.recordScreen", comment: ""),
                        subtitle: "⌘⇧5",
                        fullWidth: true
                    ) {
                        closePopover()
                        Task { await captureManager.startRecording() }
                    }
                }
            }
            .padding(12)

            Divider()

            // Last capture thumbnail
            if let thumbnail = captureManager.lastCaptureThumbnail {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("menu.lastCapture", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)

                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 80)
                        .cornerRadius(4)
                        .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)

                Divider()
            }

            // Footer
            HStack {
                Button(action: {
                    closePopover()
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    Label(NSLocalizedString("menu.settings", comment: ""), systemImage: "gear")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Label(NSLocalizedString("menu.quit", comment: ""), systemImage: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(width: fullWidth ? nil : 80, height: 70)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
