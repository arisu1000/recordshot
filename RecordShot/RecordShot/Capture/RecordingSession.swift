import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// MARK: - RecordingFormat

enum RecordingFormat: String, CaseIterable, Identifiable {
    case mp4, mov, gif

    var id: Self { self }

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .mp4: return "MP4 (H.264)"
        case .mov: return "MOV (H.264)"
        case .gif: return "GIF (Animated)"
        }
    }

    var avFileType: AVFileType? {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        case .gif: return nil
        }
    }
}

// MARK: - RecordingSession

class RecordingSession: NSObject, SCStreamOutput {
    let outputURL: URL
    let format: RecordingFormat
    weak var stream: SCStream?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isWriting = false
    private var firstSampleTime: CMTime?

    // GIF buffering — stream is already at half resolution (set by ScreenCaptureManager)
    private var gifFrames: [(image: CGImage, delay: Double)] = []
    private var lastGifFrameTime: CMTime?
    private let gifFrameInterval: Double = 0.1   // 10 fps
    private let gifMaxFrames = 150               // 15 seconds max
    private let ciContext = CIContext()

    init(outputURL: URL, displaySize: CGSize, format: RecordingFormat = .mp4) throws {
        self.outputURL = outputURL
        self.format = format
        super.init()

        if let fileType = format.avFileType {
            try setupAssetWriter(size: displaySize, fileType: fileType)
        }
    }

    private func setupAssetWriter(size: CGSize, fileType: AVFileType) throws {
        // H.264 requires even dimensions
        let w = (Int(size.width)  / 2) * 2
        let h = (Int(size.height) / 2) * 2

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)

        // H.264 for both MP4 and MOV — maximum compatibility
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        if let input = videoInput {
            assetWriter?.add(input)
        }
    }

    func startWriting() throws {
        if format == .gif {
            isWriting = true
            return
        }
        guard assetWriter?.startWriting() == true else {
            throw assetWriter?.error ?? NSError(domain: "RecordShot", code: -1)
        }
        isWriting = true
    }

    func stopWriting() async {
        guard isWriting else { return }
        isWriting = false

        if format == .gif {
            await writeGIF()
            return
        }

        videoInput?.markAsFinished()
        await withCheckedContinuation { continuation in
            assetWriter?.finishWriting {
                continuation.resume()
            }
        }
    }

    // MARK: - GIF export

    private func writeGIF() async {
        guard !gifFrames.isEmpty else { return }

        let dest = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            gifFrames.count,
            nil
        )
        guard let dest else { return }

        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(dest, fileProperties as CFDictionary)

        for (image, delay) in gifFrames {
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay
                ]
            ]
            CGImageDestinationAddImage(dest, image, frameProperties as CFDictionary)
        }

        CGImageDestinationFinalize(dest)
        gifFrames.removeAll()
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, isWriting else { return }

        if format == .gif {
            handleGIFFrame(sampleBuffer)
            return
        }

        guard let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }

        let presentationTime = sampleBuffer.presentationTimeStamp

        if firstSampleTime == nil {
            firstSampleTime = presentationTime
            assetWriter?.startSession(atSourceTime: presentationTime)
        }

        videoInput.append(sampleBuffer)
    }

    private func handleGIFFrame(_ sampleBuffer: CMSampleBuffer) {
        guard gifFrames.count < gifMaxFrames else { return }

        let presentationTime = sampleBuffer.presentationTimeStamp

        if let lastTime = lastGifFrameTime {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(presentationTime, lastTime))
            guard elapsed >= gifFrameInterval else { return }
        }

        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        // Stream is already at half resolution — just convert to CGImage
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        gifFrames.append((image: cgImage, delay: gifFrameInterval))
        lastGifFrameTime = presentationTime
    }
}
