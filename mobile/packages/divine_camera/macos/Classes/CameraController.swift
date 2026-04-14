// ABOUTME: AVFoundation-based camera controller for macOS
// ABOUTME: Handles camera initialization, preview, and controls
// ABOUTME: Recording logic in +Recording, screen flash in +ScreenFlash,
// ABOUTME: capture delegates in +Capture

import AVFoundation
import AppKit
import FlutterMacOS

/// Controller for AVFoundation-based camera operations on macOS.
/// Handles camera initialization, preview, video recording, and camera controls.
class CameraController: NSObject {
    var captureSession: AVCaptureSession?
    var videoDevice: AVCaptureDevice?
    var audioDevice: AVCaptureDevice?
    var videoInput: AVCaptureDeviceInput?
    var audioInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput?
    var audioOutput: AVCaptureAudioDataOutput?

    // AVAssetWriter for video recording
    var assetWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    var textureRegistry: FlutterTextureRegistry
    var textureId: Int64 = -1
    var pixelBufferRef: CVPixelBuffer?
    var latestSampleBuffer: CMSampleBuffer?
    let pixelBufferLock = NSLock()

    var currentLensType: String = "front"
    var isRecording: Bool = false
    var isPaused: Bool = false

    var minZoom: CGFloat = 1.0
    var maxZoom: CGFloat = 1.0
    var currentZoom: CGFloat = 1.0

    // macOS cameras are typically landscape; aspect ratio is 16:9
    var aspectRatio: CGFloat = 16.0 / 9.0

    var hasFrontCamera: Bool = false
    var hasBackCamera: Bool = false
    var isFocusPointSupported: Bool = false
    var isExposurePointSupported: Bool = false

    // Screen flash state (implementation in +ScreenFlash)
    var screenFlashWindows: [NSWindow] = []
    var currentFlashMode: String = "off"
    var isAutoFlashMode: Bool = false
    var autoFlashEnabled: Bool = false
    var screenFlashFeatureEnabled: Bool = true

    // Auto flash thresholds (same logic as iOS)
    let isoThreshold: Float = 500
    let exposureThreshold: Float = 0.040  // 40ms

    var recordingStartTime: Date?
    var currentRecordingURL: URL?
    var recordingCompletion: (([String: Any]?, String?) -> Void)?
    var maxDurationTimer: Timer?
    var maxDurationMs: Int?
    var isWriterSessionStarted: Bool = false

    /// Completion handler for camera switch
    var switchCameraCompletion: (([String: Any]?, String?) -> Void)?

    /// Completion handler for camera initialization
    var initializationCompletion: (([String: Any]?, String?) -> Void)?

    /// Timeout timer for initialization
    var initializationTimeoutTimer: Timer?

    let sessionQueue = DispatchQueue(
        label: "com.divine_camera.session"
    )
    let videoOutputQueue = DispatchQueue(
        label: "com.divine_camera.videoOutput"
    )

    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
        checkCameraAvailability()
    }

    /// Checks which cameras are available on the device.
    private func checkCameraAvailability() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        for device in discoverySession.devices {
            switch device.position {
            case .front:
                hasFrontCamera = true
            case .back:
                hasBackCamera = true
            case .unspecified:
                // On macOS, built-in cameras often report .unspecified
                // Treat them as front-facing (FaceTime camera)
                hasFrontCamera = true
            @unknown default:
                break
            }
        }

        // If no positional cameras found, check for any video device
        if !hasFrontCamera && !hasBackCamera {
            if AVCaptureDevice.default(for: .video) != nil {
                hasFrontCamera = true
            }
        }

        print(
            "[DivineCameraController] macOS cameras: "
                + "front=\(hasFrontCamera), back=\(hasBackCamera)"
        )
    }

    /// Gets metadata for the currently active camera lens.
    private func getCurrentLensMetadata() -> [String: Any]? {
        guard let device = videoDevice else {
            return nil
        }
        return extractCameraMetadata(device: device, lensType: currentLensType)
    }

    /// Extracts metadata from an AVCaptureDevice.
    private func extractCameraMetadata(
        device: AVCaptureDevice,
        lensType: String
    ) -> [String: Any] {
        let format = device.activeFormat
        let formatDescription = format.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(
            formatDescription
        )

        // lensAperture, videoFieldOfView, isVideoStabilizationModeSupported,
        // exposureDuration, and iso are unavailable on macOS.
        let aperture: Double = 0.0
        let fieldOfView: Double? = nil
        let hasOpticalStabilization = false

        // Calculate 35mm equivalent focal length from field of view
        let focalLengthEquivalent35mm: Double? = nil

        let cameraId = device.uniqueID
        let exposureDuration: Double = 0.0
        let iso: Double = 0.0

        return [
            "lensType": lensType,
            "cameraId": cameraId,
            "focalLengthEquivalent35mm": focalLengthEquivalent35mm as Any,
            "aperture": aperture,
            "pixelArrayWidth": Int(dimensions.width),
            "pixelArrayHeight": Int(dimensions.height),
            "fieldOfView": fieldOfView as Any,
            "hasOpticalStabilization": hasOpticalStabilization,
            "isLogicalCamera": false,
            "physicalCameraIds": [String](),
            "exposureDuration": exposureDuration,
            "iso": iso,
        ]
    }

    /// Returns a list of available lens types on this device.
    private func getAvailableLenses() -> [String] {
        var lenses: [String] = []
        if hasFrontCamera { lenses.append("front") }
        if hasBackCamera { lenses.append("back") }
        return lenses
    }

    /// Gets the AVCaptureDevice for the specified lens type.
    func getDeviceForLensType(_ lensType: String)
        -> AVCaptureDevice?
    {
        switch lensType {
        case "front":
            // On macOS, built-in camera often reports .unspecified
            if let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            ) {
                return device
            }
            // Fallback: try the default video device
            return AVCaptureDevice.default(for: .video)
        case "back":
            return AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )
        default:
            return AVCaptureDevice.default(for: .video)
        }
    }

    // MARK: - Initialization

    var videoQualityPreset: AVCaptureSession.Preset = .high

    /// Initializes the camera with the specified lens and video quality.
    func initialize(
        lens: String,
        videoQuality: String,
        enableAutoLensSwitch: Bool = false,
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        currentLensType = lens

        // Fallback to available camera if requested lens is not available
        if getDeviceForLensType(currentLensType) == nil {
            if hasFrontCamera {
                currentLensType = "front"
            } else if hasBackCamera {
                currentLensType = "back"
            }
        }

        // Map video quality string to AVCaptureSession.Preset
        switch videoQuality {
        case "sd":
            videoQualityPreset = .medium
        case "hd":
            videoQualityPreset = .hd1280x720
        case "fhd":
            videoQualityPreset = .hd1920x1080
        case "uhd":
            videoQualityPreset = .hd4K3840x2160
        case "highest":
            videoQualityPreset = .high
        case "lowest":
            videoQualityPreset = .low
        default:
            videoQualityPreset = .hd1920x1080
        }

        sessionQueue.async { [weak self] in
            self?.setupCamera(completion: completion)
        }
    }

    /// Sets up the camera session.
    private func setupCamera(
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        let session = AVCaptureSession()
        session.beginConfiguration()

        // Setup video input
        guard let videoDevice = getDeviceForLensType(currentLensType) else {
            completion(nil, "No camera available for lens: \(currentLensType)")
            return
        }

        self.videoDevice = videoDevice

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoInput = videoInput
            } else {
                completion(nil, "Cannot add video input")
                return
            }

            // Set preset with fallback
            let presetsToTry: [AVCaptureSession.Preset] = [
                videoQualityPreset,
                .hd4K3840x2160,
                .hd1920x1080,
                .hd1280x720,
                .high,
                .medium,
                .low,
            ]

            for preset in presetsToTry {
                if session.canSetSessionPreset(preset) {
                    session.sessionPreset = preset
                    break
                }
            }
        } catch {
            completion(
                nil,
                "Failed to create video input: \(error.localizedDescription)"
            )
            return
        }

        // Audio input/output are added during setup (same as iOS).
        // macOS shows "Call Ended" only when the microphone is removed
        // from the session or the session stops. By keeping audio in
        // the session for its entire lifetime, the notification only
        // appears once when the camera is disposed — not after every
        // recording.
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            self.audioDevice = audioDevice
            do {
                let audioInput = try AVCaptureDeviceInput(
                    device: audioDevice
                )
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    self.audioInput = audioInput
                }
            } catch {
                print(
                    "Failed to add audio input: "
                        + "\(error.localizedDescription)"
                )
            }
        }

        // Setup video output for preview
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }

        // Setup audio output for recording
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioOutput = audioOutput
        }

        session.commitConfiguration()

        // Get camera properties
        updateCameraProperties(device: videoDevice)

        // Start session
        session.startRunning()
        self.captureSession = session

        // Register texture
        textureId = textureRegistry.register(self)
        print(
            "DivineCamera macOS: Registered texture with ID: \(textureId)"
        )

        // Store completion handler
        self.initializationCompletion = completion

        // Timeout fallback
        DispatchQueue.main.async { [weak self] in
            self?.initializationTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: 2.0,
                repeats: false
            ) { [weak self] _ in
                self?.completeInitializationIfNeeded(timedOut: true)
            }
        }
    }

    /// Completes initialization when first frame is received or timeout occurs.
    func completeInitializationIfNeeded(timedOut: Bool = false) {
        initializationTimeoutTimer?.invalidate()
        initializationTimeoutTimer = nil

        guard let completion = initializationCompletion else { return }
        initializationCompletion = nil

        if timedOut {
            print(
                "DivineCamera macOS: Initialization completed via timeout"
            )
        } else {
            print(
                "DivineCamera macOS: Initialization completed - first frame"
            )
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var state = self.getCameraState()
            state["textureId"] = self.textureId
            completion(state, nil)
        }
    }

    /// Updates camera properties from the device.
    func updateCameraProperties(device: AVCaptureDevice) {
        minZoom = 1.0
        // videoMaxZoomFactor and videoZoomFactor are unavailable on macOS
        maxZoom = 1.0
        currentZoom = 1.0
        isFocusPointSupported = device.isFocusPointOfInterestSupported
        isExposurePointSupported = device.isExposurePointOfInterestSupported

        let dimensions = CMVideoFormatDescriptionGetDimensions(
            device.activeFormat.formatDescription
        )
        // macOS cameras are landscape by default
        if dimensions.height > 0 {
            aspectRatio =
                CGFloat(dimensions.width) / CGFloat(dimensions.height)
        }
    }

    // MARK: - Camera Controls

    /// Switches to a different camera lens.
    func switchCamera(
        lens: String,
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        // Disable screen flash during camera switch
        disableScreenFlash()
        disableAutoFlash()
        isAutoFlashMode = false

        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else {
                completion(nil, "Session not available")
                return
            }

            self.currentLensType = lens

            guard let newDevice = self.getDeviceForLensType(lens) else {
                completion(nil, "Lens \(lens) is not available on this device")
                return
            }

            session.beginConfiguration()

            if let oldInput = self.videoInput {
                session.removeInput(oldInput)
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)

                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.videoInput = newInput
                    self.videoDevice = newDevice
                    self.updateCameraProperties(device: newDevice)
                } else {
                    if let oldInput = self.videoInput {
                        session.addInput(oldInput)
                    }
                    session.commitConfiguration()
                    completion(nil, "Cannot add video input for new camera")
                    return
                }
            } catch {
                if let oldInput = self.videoInput {
                    session.addInput(oldInput)
                }
                session.commitConfiguration()
                completion(
                    nil,
                    "Failed to switch camera: \(error.localizedDescription)"
                )
                return
            }

            session.commitConfiguration()

            self.switchCameraCompletion = { [weak self] state, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    completion(self.getCameraState(), nil)
                }
            }
        }
    }

    /// Sets the focus point in normalized coordinates (0.0-1.0).
    func setFocusPoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice,
            device.isFocusPointOfInterestSupported
        else {
            return false
        }

        let point = CGPoint(x: x, y: y)

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    /// Sets the exposure point in normalized coordinates (0.0-1.0).
    func setExposurePoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice,
            device.isExposurePointOfInterestSupported
        else {
            return false
        }

        let point = CGPoint(x: x, y: y)

        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = point
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    /// Cancels any active focus/metering lock.
    func cancelFocusAndMetering() -> Bool {
        guard let device = videoDevice else { return false }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    /// Sets the zoom level.
    func setZoomLevel(level: CGFloat) -> Bool {
        // videoZoomFactor is unavailable on macOS
        // macOS cameras do not support programmatic zoom
        return false
    }

    // MARK: - Preview

    /// Pauses the camera preview.
    func pausePreview() {
        disableScreenFlash()
        isPaused = true
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    /// Resumes the camera preview.
    func resumePreview(
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        isPaused = false

        // Re-enable screen flash if torch mode was active
        if currentFlashMode == "torch" {
            enableScreenFlash()
        }

        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                completion(self.getCameraState(), nil)
            }
        }
    }

    // MARK: - State

    /// Gets the current camera state as a dictionary.
    func getCameraState() -> [String: Any] {
        return [
            "isInitialized": captureSession != nil,
            "isRecording": isRecording,
            "flashMode": currentFlashMode,
            "lens": currentLensType,
            "zoomLevel": Double(currentZoom),
            "minZoomLevel": Double(minZoom),
            "maxZoomLevel": Double(maxZoom),
            "aspectRatio": Double(aspectRatio),
            "hasFlash": hasFrontCamera,  // Screen flash available on front camera
            "hasFrontCamera": hasFrontCamera,
            "hasBackCamera": hasBackCamera,
            "isFocusPointSupported": isFocusPointSupported,
            "isExposurePointSupported": isExposurePointSupported,
            "textureId": textureId,
            "availableLenses": getAvailableLenses(),
            "currentLensMetadata": getCurrentLensMetadata() as Any,
        ]
    }

    // MARK: - Audio Device Management

    /// Switches the audio input device to the one with the given ID.
    ///
    /// Replaces the current audio input in the capture session without
    /// removing the audio output, so macOS does not treat the change
    /// as ending a call.
    func switchAudioDevice(to deviceId: String) {
        guard let session = captureSession,
              let newDevice = AVCaptureDevice(uniqueID: deviceId)
        else { return }

        session.beginConfiguration()

        // Remove current audio input (but keep audioOutput)
        if let currentInput = self.audioInput {
            session.removeInput(currentInput)
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.audioInput = newInput
                self.audioDevice = newDevice
                print(
                    "DivineCamera macOS: Switched audio device to "
                        + "\(newDevice.localizedName)"
                )
            }
        } catch {
            print(
                "Failed to switch audio device: "
                    + "\(error.localizedDescription)"
            )
        }

        session.commitConfiguration()
    }

    // MARK: - Cleanup

    /// Releases all camera resources.
    func release() {
        disableScreenFlash()
        disableAutoFlash()

        initializationTimeoutTimer?.invalidate()
        initializationTimeoutTimer = nil
        initializationCompletion = nil

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.isRecording {
                self.isRecording = false
                self.videoWriterInput?.markAsFinished()
                self.audioWriterInput?.markAsFinished()
                self.assetWriter?.cancelWriting()
            }

            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.videoDevice = nil
            self.audioDevice = nil
            self.videoInput = nil
            self.audioInput = nil
            self.videoOutput = nil
            self.audioOutput = nil
            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil
            self.pixelBufferAdaptor = nil

            if self.textureId >= 0 {
                self.textureRegistry.unregisterTexture(self.textureId)
                self.textureId = -1
            }

            self.pixelBufferLock.lock()
            self.latestSampleBuffer = nil
            self.pixelBufferRef = nil
            self.pixelBufferLock.unlock()
        }
    }
}
