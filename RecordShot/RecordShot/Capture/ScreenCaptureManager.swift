import Foundation
import ScreenCaptureKit
import AppKit
import AVFoundation
import UserNotifications

@MainActor
class ScreenCaptureManager: NSObject, ObservableObject {
    static let shared = ScreenCaptureManager()

    @Published var isRecording = false
    @Published var recordingTimeString = "00:00"
    @Published var lastCaptureThumbnail: NSImage?

    private var recordingSession: RecordingSession?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private let settings = AppSettings.shared
    private var editorWindows: [ImageEditorWindow] = []

    override init() {
        super.init()
    }

    // MARK: - Screenshots

    func takeFullScreenshot() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                showError(NSLocalizedString("error.noDisplay", comment: ""))
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let scaleFactor = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
            config.width = display.width * scaleFactor
            config.height = display.height * scaleFactor
            config.scalesToFit = false

            let image = try await captureImage(filter: filter, config: config)
            await saveAndCopyImage(image, prefix: "screenshot")
        } catch {
            showError(String(format: NSLocalizedString("error.screenshotFailed", comment: ""), error.localizedDescription))
        }
    }

    func takeRegionScreenshot() async {
        guard let region = await RegionSelector.selectRegion() else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                showError(NSLocalizedString("error.noDisplay", comment: ""))
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()

            // region은 RegionSelector에서 이미 top-left origin으로 변환됨
            let scaleFactor = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
            config.sourceRect = region
            config.width = Int(region.width) * scaleFactor
            config.height = Int(region.height) * scaleFactor
            config.scalesToFit = false

            let image = try await captureImage(filter: filter, config: config)
            await saveAndCopyImage(image, prefix: "region", region: region)
        } catch {
            showError(String(format: NSLocalizedString("error.regionFailed", comment: ""), error.localizedDescription))
        }
    }

    private func captureImage(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        if #available(macOS 14.0, *) {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } else {
            return try await captureImageLegacy(filter: filter, config: config)
        }
    }

    private func captureImageLegacy(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let output = SingleFrameOutput { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            do {
                try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
                stream.startCapture { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    stream.stopCapture { _ in }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func saveAndCopyImage(_ image: CGImage, prefix: String, region: CGRect? = nil) async {
        let url = generateFileURL(prefix: prefix, ext: "png")

        if let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }

        // 논리 크기(포인트)로 설정 — 항상 실제 CGImage 픽셀 크기에서 계산
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let logicalSize = NSSize(
            width: CGFloat(image.width) / scale,
            height: CGFloat(image.height) / scale
        )
        let nsImage = NSImage(cgImage: image, size: logicalSize)

        lastCaptureThumbnail = nsImage.thumbnail(maxSize: CGSize(width: 240, height: 80))

        // 편집 창을 바로 열기 — 캡처마다 새 인스턴스를 생성해 독립적으로 동작
        let editorWindow = ImageEditorWindow()
        editorWindows.append(editorWindow)

        editorWindow.onDismiss = { [weak self, weak editorWindow] in
            if let w = editorWindow {
                self?.editorWindows.removeAll { $0 === w }
            }
        }

        editorWindow.open(image: nsImage) { [weak self] edited in
            if let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil),
               let cgEdited = edited.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                CGImageDestinationAddImage(dest, cgEdited, nil)
                CGImageDestinationFinalize(dest)
            }
            self?.showNotification(title: NSLocalizedString("notification.saved", comment: ""), body: url.lastPathComponent)
        }
    }

    // MARK: - Recording

    func startRecording() async {
        guard !isRecording else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                showError(NSLocalizedString("error.noDisplay", comment: ""))
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 fps
            if #available(macOS 13.0, *) {
                config.capturesAudio = false
            }

            let outputURL = generateFileURL(prefix: "recording", ext: "mp4")
            recordingSession = try RecordingSession(outputURL: outputURL, displaySize: CGSize(width: display.width, height: display.height))

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(recordingSession!, type: .screen, sampleHandlerQueue: .global())

            try await stream.startCapture()
            recordingSession?.stream = stream
            try recordingSession?.startWriting()

            isRecording = true
            recordingStartTime = Date()
            startRecordingTimer()
            NotificationCenter.default.post(name: .recordingStateChanged, object: nil)

            // Auto-stop if duration set
            if settings.maxRecordingDuration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(settings.maxRecordingDuration)) { [weak self] in
                    Task { await self?.stopRecording() }
                }
            }
        } catch {
            showError(String(format: NSLocalizedString("error.recordingFailed", comment: ""), error.localizedDescription))
        }
    }

    func stopRecording() async {
        guard isRecording, let session = recordingSession else { return }

        isRecording = false
        stopRecordingTimer()
        NotificationCenter.default.post(name: .recordingStateChanged, object: nil)

        if let stream = session.stream {
            try? await stream.stopCapture()
        }

        await session.stopWriting()

        showNotification(title: NSLocalizedString("notification.recordingSaved", comment: ""), body: session.outputURL.lastPathComponent)
        recordingSession = nil
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            Task { @MainActor in
                self.recordingTimeString = String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTimeString = "00:00"
    }

    // MARK: - Helpers

    private func generateFileURL(prefix: String, ext: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "\(prefix)_\(timestamp).\(ext)"

        let saveDir: URL
        if settings.savePath.isEmpty {
            saveDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        } else {
            saveDir = URL(fileURLWithPath: settings.savePath)
        }

        return saveDir.appendingPathComponent(filename)
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("error.title", comment: "")
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension ScreenCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            if self.isRecording {
                await self.stopRecording()
            }
        }
    }
}

// Helper for legacy single frame capture
class SingleFrameOutput: NSObject, SCStreamOutput {
    private let completion: (Result<CGImage, Error>) -> Void
    private var didCapture = false

    init(completion: @escaping (Result<CGImage, Error>) -> Void) {
        self.completion = completion
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !didCapture, type == .screen else { return }
        didCapture = true

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            completion(.failure(NSError(domain: "RecordShot", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image buffer"])))
            return
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            completion(.failure(NSError(domain: "RecordShot", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])))
            return
        }

        completion(.success(cgImage))
        stream.stopCapture { _ in }
    }
}

extension NSImage {
    func thumbnail(maxSize: CGSize) -> NSImage {
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize))
        thumbnail.unlockFocus()
        return thumbnail
    }
}
