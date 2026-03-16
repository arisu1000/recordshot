import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section("Save Location") {
                HStack {
                    Text(settings.savePath.isEmpty ? "~/Desktop" : shortenPath(settings.savePath))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Choose...") {
                        selectSaveFolder()
                    }
                }
                Toggle("Copy to Clipboard after Capture", isOn: $settings.autoCopyToClipboard)
            }

            Section("Recording") {
                HStack {
                    Text("Max Duration")
                    Spacer()
                    if settings.maxRecordingDuration == 0 {
                        Text("Unlimited")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(settings.maxRecordingDuration) seconds")
                            .foregroundColor(.secondary)
                    }
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.maxRecordingDuration) },
                        set: { settings.maxRecordingDuration = Int($0) }
                    ),
                    in: 0...300,
                    step: 30
                )
                Text(settings.maxRecordingDuration == 0 ? "No time limit" : "Auto-stop after \(settings.maxRecordingDuration) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Keyboard Shortcuts") {
                HStack { Text("Screenshot"); Spacer(); Text("⌘⇧3").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                HStack { Text("Region Screenshot"); Spacer(); Text("⌘⇧4").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                HStack { Text("Toggle Recording"); Spacer(); Text("⌘⇧5").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                Text("Note: Requires Accessibility permission to use global shortcuts")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Open Accessibility Settings") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
            }

            Section("About") {
                HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundColor(.secondary) }
                HStack { Text("Deployment Target"); Spacer(); Text("macOS 12.3+").foregroundColor(.secondary) }
            }
        }
        .frame(width: 450, height: 500)
        .navigationTitle("RecordShot Settings")
    }

    private func selectSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            settings.savePath = url.path
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
