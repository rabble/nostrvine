// ABOUTME: Recording extension for CameraController
// ABOUTME: Handles AVAssetWriter-based video recording, start/stop, and auto-stop

import AVFoundation
import Foundation

extension CameraController {

    /// Starts video recording using AVAssetWriter.
    func startRecording(
        maxDurationMs: Int?,
        useCache: Bool = true,
        outputDirectory: String? = nil,
        audioDeviceId: String? = nil,
        completion: @escaping (String?) -> Void
    ) {
        if isRecording {
            completion("Already recording")
            return
        }

        // Check and enable auto-flash if needed
        checkAndEnableAutoFlash()

        self.maxDurationMs = maxDurationMs

        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }

            let outputDir: URL
            if let customDir = outputDirectory {
                outputDir = URL(fileURLWithPath: customDir)
            } else if useCache {
                outputDir = FileManager.default.temporaryDirectory
            } else {
                let paths = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                )
                outputDir = paths[0]
            }

            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let outputURL = outputDir.appendingPathComponent(
                "VID_\(timestamp).mp4"
            )
            self.currentRecordingURL = outputURL

            try? FileManager.default.removeItem(at: outputURL)

            do {
                let writer = try AVAssetWriter(
                    outputURL: outputURL,
                    fileType: .mp4
                )

                guard let device = self.videoDevice else {
                    DispatchQueue.main.async {
                        completion("Video device not available")
                    }
                    return
                }

                let dimensions = CMVideoFormatDescriptionGetDimensions(
                    device.activeFormat.formatDescription
                )
                // macOS cameras are landscape—width is the longer side
                let videoWidth = Int(dimensions.width)
                let videoHeight = Int(dimensions.height)

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: videoWidth,
                    AVVideoHeightKey: videoHeight,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 6_000_000,
                        AVVideoProfileLevelKey:
                            AVVideoProfileLevelH264HighAutoLevel,
                    ],
                ]

                let videoInput = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: videoSettings
                )
                videoInput.expectsMediaDataInRealTime = true

                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: videoWidth,
                    kCVPixelBufferHeightKey as String: videoHeight,
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )

                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 64000,
                ]
                let audioInput = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: audioSettings
                )
                audioInput.expectsMediaDataInRealTime = true

                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                }

                self.assetWriter = writer
                self.videoWriterInput = videoInput
                self.audioWriterInput = audioInput
                self.pixelBufferAdaptor = adaptor

                writer.startWriting()

                // Switch to the preferred audio device if specified.
                // The audio input/output stay in the session for its
                // entire lifetime (added during setupCamera).
                if let deviceId = audioDeviceId {
                    self.switchAudioDevice(to: deviceId)
                }

                self.isRecording = true
                self.isWriterSessionStarted = false
                self.recordingStartTime = Date()

                print(
                    "DivineCamera macOS: Recording started to \(outputURL.path)"
                )

                // Schedule max duration timer if specified
                if let maxMs = maxDurationMs, maxMs > 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.maxDurationTimer = Timer.scheduledTimer(
                            withTimeInterval: Double(maxMs) / 1000.0,
                            repeats: false
                        ) { [weak self] _ in
                            self?.autoStopRecording()
                        }
                    }
                }

                DispatchQueue.main.async {
                    completion(nil)
                }

            } catch {
                DispatchQueue.main.async {
                    completion(
                        "Failed to create asset writer: "
                            + "\(error.localizedDescription)"
                    )
                }
            }
        }
    }

    /// Automatically stops recording when max duration is reached.
    func autoStopRecording() {
        guard isRecording else { return }

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        stopRecording { result, _ in
            if let result = result {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DivineCameraAutoStop"),
                    object: nil,
                    userInfo: result
                )
            }
        }
    }

    /// Stops video recording and returns the result.
    func stopRecording(
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        guard isRecording, let writer = assetWriter else {
            completion(nil, "Not recording")
            return
        }

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        isRecording = false

        // Disable auto-flash when recording stops
        disableAutoFlash()

        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }

            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if writer.status == .completed {
                        let duration: Int
                        if let startTime = self.recordingStartTime {
                            duration = Int(
                                Date().timeIntervalSince(startTime) * 1000
                            )
                        } else {
                            duration = 0
                        }

                        guard let outputURL = self.currentRecordingURL else {
                            completion(nil, "Output URL not available")
                            return
                        }

                        var width: Int = 1920
                        var height: Int = 1080

                        // Use the known recording dimensions from the
                        // active format rather than loading from the asset
                        // (the async AVAsset API cannot be used here).
                        if let device = self.videoDevice {
                            let dims = CMVideoFormatDescriptionGetDimensions(
                                device.activeFormat.formatDescription
                            )
                            width = Int(dims.width)
                            height = Int(dims.height)
                        }

                        let result: [String: Any] = [
                            "filePath": outputURL.path,
                            "durationMs": duration,
                            "width": width,
                            "height": height,
                        ]

                        print(
                            "DivineCamera macOS: Recording completed - "
                                + "\(outputURL.path)"
                        )
                        completion(result, nil)
                    } else {
                        completion(
                            nil,
                            "Recording failed: "
                                + "\(writer.error?.localizedDescription ?? "Unknown error")"
                        )
                    }

                    // Audio is intentionally kept in the session
                    // after recording stops. Removing it triggers
                    // macOS "Call Ended" notification. It will be
                    // cleaned up when the camera is disposed.

                    // Cleanup
                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                    self.pixelBufferAdaptor = nil
                    self.currentRecordingURL = nil
                    self.recordingStartTime = nil
                    self.isWriterSessionStarted = false
                }
            }
        }
    }
}
