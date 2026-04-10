import SwiftUI
import AppKit
import ScreenCaptureKit

@MainActor
class OnboardingWindow {
    private var window: NSWindow?

    func show() {
        let view = OnboardingView(onDismiss: { [weak self] in
            self?.window?.close()
            self?.window = nil
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        })

        let hostingController = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hostingController)
        w.title = NSLocalizedString("onboarding.title", comment: "")
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 480, height: 420))
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .floating

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }
}

struct OnboardingView: View {
    let onDismiss: () -> Void
    @State private var screenCaptureGranted = false
    @State private var accessibilityGranted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("onboarding.welcome", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(NSLocalizedString("onboarding.description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Permission steps
            VStack(spacing: 16) {
                PermissionRow(
                    step: "1",
                    icon: "rectangle.dashed.badge.record",
                    title: NSLocalizedString("onboarding.screenRecording", comment: ""),
                    description: NSLocalizedString("onboarding.screenRecordingDesc", comment: ""),
                    isGranted: screenCaptureGranted,
                    buttonTitle: NSLocalizedString("onboarding.openScreenRecording", comment: ""),
                    action: {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                        NSWorkspace.shared.open(url)
                    }
                )

                PermissionRow(
                    step: "2",
                    icon: "hand.raised.fill",
                    title: NSLocalizedString("onboarding.accessibility", comment: ""),
                    description: NSLocalizedString("onboarding.accessibilityDesc", comment: ""),
                    isGranted: accessibilityGranted,
                    buttonTitle: NSLocalizedString("onboarding.openAccessibility", comment: ""),
                    action: {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Text(NSLocalizedString("onboarding.hint", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onDismiss) {
                    Text(NSLocalizedString("onboarding.start", comment: ""))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 420)
        .onAppear { checkPermissions() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            checkPermissions()
        }
    }

    private func checkPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                screenCaptureGranted = true
            } catch {
                screenCaptureGranted = false
            }
        }
    }
}

struct PermissionRow: View {
    let step: String
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green : Color.accentColor)
                    .frame(width: 28, height: 28)
                if isGranted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(step)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                    Text(title)
                        .fontWeight(.medium)
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !isGranted {
                    Button(buttonTitle, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(isGranted ? Color.green.opacity(0.05) : Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}
