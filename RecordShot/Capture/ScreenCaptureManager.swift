import Foundation
import ScreenCaptureKit
import AppKit
import AVFoundation
import UserNotifications
import UniformTypeIdentifiers

@MainActor
class ScreenCaptureManager: NSObject, ObservableObject {
    static let shared = ScreenCaptureManager()

    @Published var isRecording = false
    @Published var recordingTimeString = "00:00"
    @Published var lastCaptureThumbnail: NSImage?
    @Published var lastRecordingURL: URL?

    private var recordingSession: RecordingSession?
    private var activeStream: SCStream?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private let settings = AppSettings.shared
    private var editorWindows: [ImageEditorWindow] = []
    private var regionIndicator: RecordingRegionIndicator?
    private let streamOutputQueue = DispatchQueue(label: "com.recordshot.stream", qos: .userInteractive)

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
            // SCDisplay.width/height는 이미 물리 픽셀 단위 — scaleFactor 곱하지 않음
            config.width = display.width
            config.height = display.height
            config.scalesToFit = false

            let image = try await captureImage(filter: filter, config: config)
            await saveAndCopyImage(image, prefix: "screenshot")
        } catch {
            showError(String(format: NSLocalizedString("error.screenshotFailed", comment: ""), error.localizedDescription))
        }
    }

    func takeRegionScreenshot() async {
        guard let region = await RegionSelector.selectRegion() else { return }

        // 오버레이 창이 닫힌 후 화면 합성기가 업데이트될 때까지 대기
        try? await Task.sleep(nanoseconds: 150_000_000)

        // CGWindowListCreateImage는 top-left origin 스크린 좌표(포인트)를 직접 받아
        // 네이티브 해상도로 캡처 — 좌표 변환 불필요
        guard let image = CGWindowListCreateImage(
            region,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            showError(NSLocalizedString("error.regionFailed", comment: ""))
            return
        }

        await saveAndCopyImage(image, prefix: "region")
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
                    // Guard: SingleFrameOutput may have already resumed the continuation
                    if let error = error, !output.didCapture {
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
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0

        savePNG(image, to: url, scale: scale)

        // 논리 크기(포인트)로 설정 — 캔버스 frame이 올바른 포인트 크기를 갖도록 보장
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

        editorWindow.open(image: nsImage, originalCGImage: image) { [weak self] cgResult in
            guard let self else { return }
            // CGImage가 파이프라인 전체에서 직접 전달되므로 NSImage 변환 없이 원본 해상도 보존
            self.savePNG(cgResult, to: url, scale: scale)
            if self.settings.autoCopyToClipboard {
                let logicalSize = NSSize(
                    width: CGFloat(cgResult.width) / scale,
                    height: CGFloat(cgResult.height) / scale
                )
                ClipboardManager.copyImage(NSImage(cgImage: cgResult, size: logicalSize))
            }
            self.showNotification(title: NSLocalizedString("notification.saved", comment: ""), body: url.lastPathComponent)
        }
    }

    /// PNG로 저장하면서 DPI 메타데이터를 포함시켜 Preview 등에서 올바른 논리 크기로 표시
    private func savePNG(_ image: CGImage, to url: URL, scale: CGFloat) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        let dpi = 72.0 * scale
        let ppm = Int(dpi * 39.3701)  // dots per metre
        let props: [CFString: Any] = [
            kCGImagePropertyDPIWidth:  dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGXPixelsPerMeter: ppm,
                kCGImagePropertyPNGYPixelsPerMeter: ppm
            ] as [CFString: Any]
        ]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    // MARK: - Recording

    func startRecording() async {
        await startRecordingCore(region: nil)
    }

    func startRegionRecording() async {
        guard let region = await RegionSelector.selectRegion() else { return }
        await startRecordingCore(region: region)
    }

    private func startRecordingCore(region: CGRect?) async {
        guard !isRecording else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                showError(NSLocalizedString("error.noDisplay", comment: ""))
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()

            let baseWidth: Int
            let baseHeight: Int
            if let region = region {
                config.sourceRect = region
                baseWidth = Int(region.width)
                baseHeight = Int(region.height)
            } else {
                baseWidth = display.width
                baseHeight = display.height
            }

            let format = RecordingFormat(rawValue: settings.recordingFormat) ?? .mp4

            // H.264/HEVC require even dimensions; GIF captures at half resolution
            let captureWidth: Int
            let captureHeight: Int
            if format == .gif {
                captureWidth  = max(2, (baseWidth  / 2) & ~1)
                captureHeight = max(2, (baseHeight / 2) & ~1)
            } else {
                captureWidth  = baseWidth  & ~1
                captureHeight = baseHeight & ~1
            }

            config.width = captureWidth
            config.height = captureHeight
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 fps
            if #available(macOS 13.0, *) {
                config.capturesAudio = false
            }

            let outputURL = generateFileURL(prefix: "recording", ext: format.fileExtension, isRecording: true)
            recordingSession = try RecordingSession(
                outputURL: outputURL,
                displaySize: CGSize(width: captureWidth, height: captureHeight),
                format: format
            )

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(recordingSession!, type: .screen, sampleHandlerQueue: streamOutputQueue)

            try await stream.startCapture()
            activeStream = stream          // strong reference — keeps stream alive during recording
            recordingSession?.stream = stream
            try recordingSession?.startWriting()

            isRecording = true
            recordingStartTime = Date()
            startRecordingTimer()
            NotificationCenter.default.post(name: .recordingStateChanged, object: nil)

            if let region = region {
                regionIndicator = RecordingRegionIndicator()
                regionIndicator?.show(region: region)
            }

            // Auto-stop if duration set
            if settings.maxRecordingDuration > 0 {
                let duration = settings.maxRecordingDuration
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000_000)
                    await self?.stopRecording()
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
        regionIndicator?.hide()
        regionIndicator = nil
        NotificationCenter.default.post(name: .recordingStateChanged, object: nil)

        if let stream = activeStream {
            try? await stream.stopCapture()
        }
        activeStream = nil

        await session.stopWriting()

        let savedURL = session.outputURL
        lastRecordingURL = savedURL
        showNotification(title: NSLocalizedString("notification.recordingSaved", comment: ""), body: savedURL.lastPathComponent)
        NSWorkspace.shared.activateFileViewerSelecting([savedURL])
        recordingSession = nil
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                let elapsed = Int(Date().timeIntervalSince(start))
                self.recordingTimeString = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTimeString = "00:00"
    }

    // MARK: - Helpers

    private func generateFileURL(prefix: String, ext: String, isRecording: Bool = false) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "\(prefix)_\(timestamp).\(ext)"

        let pathStr = isRecording ? settings.recordingSavePath : settings.savePath
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let saveDir = pathStr.isEmpty ? desktop : URL(fileURLWithPath: pathStr)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

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
class SingleFrameOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let completion: (Result<CGImage, Error>) -> Void
    private(set) var didCapture = false

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
