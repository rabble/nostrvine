// ABOUTME: AVFoundation-based camera controller for macOS
// ABOUTME: Handles camera initialization, preview, recording, and controls

import AVFoundation
import AppKit
import FlutterMacOS

/// Controller for AVFoundation-based camera operations on macOS.
/// Handles camera initialization, preview, video recording, and camera controls.
class CameraController: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var audioDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?

    // AVAssetWriter for video recording
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var textureRegistry: FlutterTextureRegistry
    private var textureId: Int64 = -1
    private var pixelBufferRef: CVPixelBuffer?
    private var latestSampleBuffer: CMSampleBuffer?
    private let pixelBufferLock = NSLock()

    private var currentLensType: String = "front"
    private var isRecording: Bool = false
    private var isPaused: Bool = false

    private var minZoom: CGFloat = 1.0
    private var maxZoom: CGFloat = 1.0
    private var currentZoom: CGFloat = 1.0

    // macOS cameras are typically landscape; aspect ratio is 16:9
    private var aspectRatio: CGFloat = 16.0 / 9.0

    private var hasFrontCamera: Bool = false
    private var hasBackCamera: Bool = false
    private var isFocusPointSupported: Bool = false
    private var isExposurePointSupported: Bool = false

    // Screen flash: warm-white overlay windows that illuminate the face
    // via the display, similar to Apple's FaceTime/Photo Booth screen flash.
    private var screenFlashWindows: [NSWindow] = []
    private var currentFlashMode: String = "off"
    private var isAutoFlashMode: Bool = false
    private var autoFlashEnabled: Bool = false
    private var screenFlashFeatureEnabled: Bool = true

    // Auto flash thresholds (same logic as iOS)
    private let isoThreshold: Float = 500
    private let exposureThreshold: Float = 0.040  // 40ms

    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    private var recordingCompletion: (([String: Any]?, String?) -> Void)?
    private var maxDurationTimer: Timer?
    private var maxDurationMs: Int?
    private var isWriterSessionStarted: Bool = false

    /// Completion handler for camera switch
    private var switchCameraCompletion: (([String: Any]?, String?) -> Void)?

    /// Completion handler for camera initialization
    private var initializationCompletion: (([String: Any]?, String?) -> Void)?

    /// Timeout timer for initialization
    private var initializationTimeoutTimer: Timer?

    private let sessionQueue = DispatchQueue(
        label: "com.divine_camera.session"
    )
    private let videoOutputQueue = DispatchQueue(
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
    private func getDeviceForLensType(_ lensType: String)
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

    private var videoQualityPreset: AVCaptureSession.Preset = .high

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
    private func completeInitializationIfNeeded(timedOut: Bool = false) {
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
    private func updateCameraProperties(device: AVCaptureDevice) {
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

    // MARK: - Screen Flash

    /// Creates warm-white overlay windows on all screens to act as a fill light
    /// for the FaceTime camera. Each screen gets a borderless, topmost window
    /// with a rounded-rect ring at the edges (matching macOS rounded display
    /// corners) and a transparent centre so the camera preview stays visible.
    private func enableScreenFlash() {
        guard screenFlashFeatureEnabled else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Already showing
            if !self.screenFlashWindows.isEmpty { return }

            for screen in NSScreen.screens {
                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false
                )
                window.level = .screenSaver
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.backgroundColor = .clear
                window.collectionBehavior = [
                    .canJoinAllSpaces,
                    .stationary,
                ]

                let flashView = ScreenFlashRingView(
                    frame: NSRect(
                        origin: .zero,
                        size: screen.frame.size
                    )
                )
                window.contentView = flashView

                window.orderFrontRegardless()
                self.screenFlashWindows.append(window)
            }

            print("DivineCamera macOS: Screen flash enabled")
        }
    }

    /// Removes all screen flash overlay windows.
    private func disableScreenFlash() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let hadWindows = !self.screenFlashWindows.isEmpty
            for window in self.screenFlashWindows {
                window.orderOut(nil)
            }
            self.screenFlashWindows.removeAll()
            if hadWindows {
                print("DivineCamera macOS: Screen flash disabled")
            }
        }
    }

    /// Checks if the current environment is dark based on camera exposure.
    private func isEnvironmentDark() -> Bool {
        // iso and exposureDuration are unavailable on macOS
        // Default to not-dark so screen flash is only triggered manually
        return false
    }

    /// Checks exposure values and enables auto-flash if needed.
    /// Called when recording starts.
    private func checkAndEnableAutoFlash() {
        guard isAutoFlashMode else { return }

        if isEnvironmentDark() {
            print(
                "DivineCamera macOS: Auto flash: "
                    + "Dark environment detected - enabling screen flash"
            )
            autoFlashEnabled = true
            enableScreenFlash()
        } else {
            print(
                "DivineCamera macOS: Auto flash: "
                    + "Bright environment - flash not needed"
            )
        }
    }

    /// Disables auto-flash if it was enabled.
    private func disableAutoFlash() {
        if autoFlashEnabled {
            disableScreenFlash()
            autoFlashEnabled = false
        }
    }

    /// Sets the flash mode.
    /// On macOS the only flash mechanism is the screen flash (warm overlay).
    func setFlashMode(mode: String) -> Bool {
        print("DivineCamera macOS: Setting flash mode: \(mode)")

        switch mode {
        case "off":
            disableScreenFlash()
            currentFlashMode = "off"
            isAutoFlashMode = false
            autoFlashEnabled = false

        case "auto":
            disableScreenFlash()
            currentFlashMode = "auto"
            isAutoFlashMode = true
            autoFlashEnabled = false

        case "torch":
            enableScreenFlash()
            currentFlashMode = "torch"
            isAutoFlashMode = false

        case "on":
            currentFlashMode = "on"
            isAutoFlashMode = false

        default:
            break
        }

        return true
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

    // MARK: - Recording

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
    private func autoStopRecording() {
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
    private func switchAudioDevice(to deviceId: String) {
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
                }

                if writer.status == .writing
                    && videoInput.isReadyForMoreMediaData
                {
                    adaptor.append(
                        pixelBuffer,
                        withPresentationTime: timestamp
                    )
                }
            }
        } else if output == audioOutput {
            if isRecording, let writer = assetWriter,
                let audioInput = audioWriterInput
            {
                if isWriterSessionStarted && writer.status == .writing
                    && audioInput.isReadyForMoreMediaData
                {
                    audioInput.append(sampleBuffer)
                }
            }
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraController: AVCaptureAudioDataOutputSampleBufferDelegate {
    // Audio samples are handled in the captureOutput method above
}

// MARK: - Screen Flash Ring View

/// Custom NSView that draws a warm-white rounded-rect ring matching
/// modern macOS display corners. The centre is transparent so the camera
/// preview remains visible while the border glows.
private class ScreenFlashRingView: NSView {

    /// Corner radius matching modern MacBook / Studio Display bezels.
    private let displayCornerRadius: CGFloat = 30

    /// Width of the illuminated ring border.
    private let ringWidth: CGFloat = 80

    /// Warm-white colour (~5200 K) used for the flash ring.
    private let warmWhite = NSColor(
        calibratedRed: 1.0,
        green: 0.95,
        blue: 0.85,
        alpha: 1
    )

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        // Small inset so the ring doesn't sit flush against the screen edge
        let outerInset: CGFloat = 20
        let outerRect = bounds.insetBy(dx: outerInset, dy: outerInset)
        let outerPath = CGPath(
            roundedRect: outerRect,
            cornerWidth: displayCornerRadius,
            cornerHeight: displayCornerRadius,
            transform: nil
        )

        let innerRect = outerRect.insetBy(dx: ringWidth, dy: ringWidth)
        let innerCorner: CGFloat = 12
        let innerPath = CGPath(
            roundedRect: innerRect,
            cornerWidth: innerCorner,
            cornerHeight: innerCorner,
            transform: nil
        )

        // Build a ring: outer path with inner path cut out (even-odd fill)
        let ringPath = CGMutablePath()
        ringPath.addPath(outerPath)
        ringPath.addPath(innerPath)

        context.beginPath()
        context.addPath(ringPath)
        context.setFillColor(warmWhite.cgColor)
        context.fillPath(using: .evenOdd)
    }
}
