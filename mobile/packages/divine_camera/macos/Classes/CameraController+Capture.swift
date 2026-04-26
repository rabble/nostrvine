// ABOUTME: Capture delegate and texture extension for CameraController
// ABOUTME: Handles FlutterTexture protocol and AVCaptureOutput sample buffers

import AVFoundation
import FlutterMacOS

// MARK: - FlutterTexture

extension CameraController: FlutterTexture {
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }

        guard let pixelBuffer = pixelBufferRef else {
            return nil
        }
        return Unmanaged.passRetained(pixelBuffer)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isPaused else { return }

        if output == videoOutput {
            guard
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else {
                return
            }

            pixelBufferLock.lock()
            let isFirstFrame = latestSampleBuffer == nil
            latestSampleBuffer = sampleBuffer
            pixelBufferRef = pixelBuffer
            pixelBufferLock.unlock()

            if isFirstFrame {
                print(
                    "DivineCamera macOS: First frame received! "
                        + "\(CVPixelBufferGetWidth(pixelBuffer))"
                        + "x\(CVPixelBufferGetHeight(pixelBuffer))"
                )
                DispatchQueue.main.async { [weak self] in
                    self?.completeInitializationIfNeeded(timedOut: false)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.textureId >= 0 else { return }
                self.textureRegistry.textureFrameAvailable(self.textureId)
            }

            // Complete camera switch if waiting for first frame from new camera
            if let switchCompletion = switchCameraCompletion {
                switchCameraCompletion = nil
                let state = getCameraState()
                switchCompletion(state, nil)
            }

            // Write video frame to asset writer if recording
            if isRecording, let writer = assetWriter,
                let videoInput = videoWriterInput,
                let adaptor = pixelBufferAdaptor
            {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(
                    sampleBuffer
                )

                if !isWriterSessionStarted && writer.status == .writing {
                    writer.startSession(atSourceTime: timestamp)
                    isWriterSessionStarted = true
                    print(
                        "DivineCamera macOS: Writer session started at "
                            + "\(timestamp.seconds)"
                    )
                }

                if writer.status == .writing
                    && videoInput.isReadyForMoreMediaData
                {
                    let appended = adaptor.append(
                        pixelBuffer,
                        withPresentationTime: timestamp
                    )
                    if !appended {
                        print(
                            "DivineCamera macOS: Failed to append video frame: "
                                + "\(writer.error?.localizedDescription ?? "Unknown error")"
                        )
                    }
                }
            }
        } else if output == audioOutput {
            if isRecording, let writer = assetWriter,
                let audioInput = audioWriterInput
            {
                if isWriterSessionStarted && writer.status == .writing
                    && audioInput.isReadyForMoreMediaData
                {
                    let appended = audioInput.append(sampleBuffer)
                    if !appended {
                        print(
                            "DivineCamera macOS: Failed to append audio frame: "
                                + "\(writer.error?.localizedDescription ?? "Unknown error")"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraController: AVCaptureAudioDataOutputSampleBufferDelegate {
    // Audio samples are handled in the captureOutput method above
}
