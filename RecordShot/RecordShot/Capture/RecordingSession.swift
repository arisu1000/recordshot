import Foundation
import AVFoundation
import ScreenCaptureKit

class RecordingSession: NSObject, SCStreamOutput {
    let outputURL: URL
    weak var stream: SCStream?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isWriting = false
    private var firstSampleTime: CMTime?

    init(outputURL: URL, displaySize: CGSize) throws {
        self.outputURL = outputURL
        super.init()

        try setupAssetWriter(size: displaySize)
    }

    private func setupAssetWriter(size: CGSize) throws {
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]

        if let input = videoInput {
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: sourceAttributes
            )
            assetWriter?.add(input)
        }
    }

    func startWriting() throws {
        guard assetWriter?.startWriting() == true else {
            throw assetWriter?.error ?? NSError(domain: "RecordShot", code: -1)
        }
        isWriting = true
    }

    func stopWriting() async {
        guard isWriting else { return }
        isWriting = false

        videoInput?.markAsFinished()

        await withCheckedContinuation { continuation in
            assetWriter?.finishWriting {
                continuation.resume()
            }
        }
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, isWriting,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }

        let presentationTime = sampleBuffer.presentationTimeStamp

        if firstSampleTime == nil {
            firstSampleTime = presentationTime
            assetWriter?.startSession(atSourceTime: presentationTime)
        }

        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: presentationTime)
    }
}
