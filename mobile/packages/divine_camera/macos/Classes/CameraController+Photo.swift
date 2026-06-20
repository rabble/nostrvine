// ABOUTME: Single-photo (stop-motion) capture extension for macOS CameraController
// ABOUTME: Grabs the latest preview pixel buffer and writes it to disk as JPEG

import AppKit
import AVFoundation
import CoreImage

extension CameraController {
    /// Captures a single still photo and writes it to disk as JPEG.
    ///
    /// macOS deploys to 10.14 where `AVCapturePhotoOutput.fileDataRepresentation`
    /// is unavailable, so this grabs the most recent preview frame (the same
    /// buffer that drives the texture) and encodes it. Completion receives a
    /// result map (`filePath`, `width`, `height`) on success, or nil plus an
    /// error message on failure. Rejected while a video recording is in progress.
    func capturePhoto(
        outputDirectory: String?,
        useCache: Bool,
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isRecording else {
                completion(nil, "Cannot capture photo while recording")
                return
            }

            self.pixelBufferLock.lock()
            let buffer = self.pixelBufferRef
            self.pixelBufferLock.unlock()

            guard let pixelBuffer = buffer else {
                completion(nil, "No frame available")
                return
            }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let ciContext = CIContext()
            guard
                let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
            else {
                completion(nil, "Failed to render frame")
                return
            }

            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard
                let data = bitmap.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: 0.9]
                )
            else {
                completion(nil, "Failed to encode JPEG")
                return
            }

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
            let outputURL = outputDir.appendingPathComponent("IMG_\(timestamp).jpg")

            do {
                try FileManager.default.createDirectory(
                    at: outputDir,
                    withIntermediateDirectories: true
                )
                try data.write(to: outputURL)
                completion(
                    [
                        "filePath": outputURL.path,
                        "width": CVPixelBufferGetWidth(pixelBuffer),
                        "height": CVPixelBufferGetHeight(pixelBuffer),
                    ],
                    nil
                )
            } catch {
                completion(nil, error.localizedDescription)
            }
        }
    }
}
