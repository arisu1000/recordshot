import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section(NSLocalizedString("settings.general", comment: "")) {
                Picker(NSLocalizedString("settings.launchAction", comment: ""), selection: $settings.launchAction) {
                    ForEach(LaunchAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(NSLocalizedString("settings.saveLocation", comment: "")) {
                HStack {
                    Text(settings.savePath.isEmpty ? "~/Desktop" : shortenPath(settings.savePath))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(NSLocalizedString("settings.choose", comment: "")) {
                        selectSaveFolder()
                    }
                }
                Toggle(NSLocalizedString("settings.autoCopy", comment: ""), isOn: $settings.autoCopyToClipboard)
            }

            Section(NSLocalizedString("settings.recording", comment: "")) {
                HStack {
                    Text(NSLocalizedString("settings.recordingSaveLocation", comment: ""))
                    Spacer()
                    Text(shortenPath(settings.recordingSavePath))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 180, alignment: .trailing)
                    Button(NSLocalizedString("settings.choose", comment: "")) {
                        selectRecordingFolder()
                    }
                }

                Picker(NSLocalizedString("settings.recordingFormat", comment: ""), selection: $settings.recordingFormat) {
                    ForEach(RecordingFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt.rawValue)
                    }
                }
                .pickerStyle(.menu)

                if settings.recordingFormat == RecordingFormat.gif.rawValue {
                    Text(NSLocalizedString("settings.gifNote", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(NSLocalizedString("settings.maxDuration", comment: ""))
                    Spacer()
                    if settings.maxRecordingDuration == 0 {
                        Text(NSLocalizedString("settings.unlimited", comment: ""))
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
                Text(settings.maxRecordingDuration == 0
                    ? NSLocalizedString("settings.noTimeLimit", comment: "")
                    : String(format: NSLocalizedString("settings.autoStop", comment: ""), settings.maxRecordingDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(NSLocalizedString("settings.shortcuts", comment: "")) {
                HStack { Text(NSLocalizedString("settings.screenshot", comment: "")); Spacer(); Text("⌘⇧3").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                HStack { Text(NSLocalizedString("settings.regionScreenshot", comment: "")); Spacer(); Text("⌘⇧4").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                HStack { Text(NSLocalizedString("settings.toggleRecording", comment: "")); Spacer(); Text("⌘⇧5").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                HStack { Text(NSLocalizedString("settings.regionRecord", comment: "")); Spacer(); Text("⌘⇧6").font(.system(.body, design: .monospaced)).foregroundColor(.secondary) }
                Text(NSLocalizedString("settings.shortcutNote", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(NSLocalizedString("settings.openAccessibility", comment: "")) {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
            }

            Section(NSLocalizedString("settings.about", comment: "")) {
                HStack { Text(NSLocalizedString("settings.version", comment: "")); Spacer(); Text("1.0.0").foregroundColor(.secondary) }
                HStack { Text(NSLocalizedString("settings.deploymentTarget", comment: "")); Spacer(); Text("macOS 12.3+").foregroundColor(.secondary) }
            }
        }
        .frame(width: 480, height: 600)
        .navigationTitle(NSLocalizedString("settings.title", comment: ""))
    }

    private func selectRecordingFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("settings.selectFolder", comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            settings.recordingSavePath = url.path
        }
    }

    private func selectSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("settings.selectFolder", comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            settings.savePath = url.path
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path.isEmpty ? "~/Desktop" : path
    }
}
