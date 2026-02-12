// ABOUTME: AVFoundation-based camera controller for iOS
// ABOUTME: Handles camera initialization, preview, recording, and controls

import AVFoundation
import Flutter
import UIKit

/// Controller for AVFoundation-based camera operations.
/// Handles camera initialization, preview, video recording, and camera controls.
class CameraController: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var audioDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    
    // AVAssetWriter for video recording (replaces AVCaptureMovieFileOutput)
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var textureRegistry: FlutterTextureRegistry
    private var textureId: Int64 = -1
    private var pixelBufferRef: CVPixelBuffer?
    private var latestSampleBuffer: CMSampleBuffer?
    private let pixelBufferLock = NSLock()
    
    private var currentLens: AVCaptureDevice.Position = .back
    private var currentFlashMode: AVCaptureDevice.FlashMode = .off
    private var currentTorchMode: AVCaptureDevice.TorchMode = .off
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    
    // Screen brightness for front camera "torch" mode
    private var originalBrightness: CGFloat?
    private var screenFlashFeatureEnabled: Bool = true
    
    // Whether to mirror front camera video output
    private var mirrorFrontCameraOutput: Bool = true
    
    // Auto flash mode - checks brightness once when recording starts
    private var isAutoFlashMode: Bool = false
    private var autoFlashTorchEnabled: Bool = false
    
    // Thresholds for "dark" detection:
    // iOS keeps ISO low and uses longer exposure times, so we need higher exposure thresholds
    // Front camera: Higher exposure threshold since screen flash is less intrusive
    // Back camera: Higher thresholds to avoid triggering in normal indoor light
    private let frontCameraIsoThreshold: Float = 500
    private let frontCameraExposureThreshold: Float = 0.040  // 40ms
    private let backCameraIsoThreshold: Float = 600
    private let backCameraExposureThreshold: Float = 0.030  // 30ms
    
    private var minZoom: CGFloat = 1.0
    private var maxZoom: CGFloat = 1.0
    private var currentZoom: CGFloat = 1.0
    // Portrait-Modus: 9:16, e.g: 1080x1920
    private var aspectRatio: CGFloat = 9.0 / 16.0
    
    private var hasFrontCamera: Bool = false
    private var hasBackCamera: Bool = false
    private var hasFlash: Bool = false
    private var isFocusPointSupported: Bool = false
    private var isExposurePointSupported: Bool = false
    
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    private var recordingCompletion: (([String: Any]?, String?) -> Void)?
    private var maxDurationTimer: Timer?
    private var maxDurationMs: Int?
    private var isWriterSessionStarted: Bool = false
    
    private let sessionQueue = DispatchQueue(label: "com.divine_camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.divine_camera.videoOutput")
    
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
            default:
                break
            }
        }
    }
    
    /// Initializes the camera with the specified lens.
    private var videoQualityPreset: AVCaptureSession.Preset = .high
    
    /// Initializes the camera with the specified lens and video quality.
    func initialize(lens: String, videoQuality: String, enableScreenFlash: Bool = true, mirrorFrontCameraOutput: Bool = true, completion: @escaping ([String: Any]?, String?) -> Void) {
        currentLens = lens == "front" ? .front : .back
        screenFlashFeatureEnabled = enableScreenFlash
        self.mirrorFrontCameraOutput = mirrorFrontCameraOutput
        
        // Fallback to available camera if requested camera is not available
        if currentLens == .front && !hasFrontCamera && hasBackCamera {
            print("[DivineCameraController] Front camera requested but not available, falling back to back camera")
            currentLens = .back
        } else if currentLens == .back && !hasBackCamera && hasFrontCamera {
            print("[DivineCameraController] Back camera requested but not available, falling back to front camera")
            currentLens = .front
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
            if #available(iOS 9.0, *) {
                videoQualityPreset = .hd4K3840x2160
            } else {
                videoQualityPreset = .hd1920x1080
            }
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
    private func setupCamera(completion: @escaping ([String: Any]?, String?) -> Void) {
        // Create capture session
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Set preset based on configured video quality
        if session.canSetSessionPreset(videoQualityPreset) {
            session.sessionPreset = videoQualityPreset
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        
        // Setup video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentLens) else {
            completion(nil, "No camera available for position")
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
        } catch {
            completion(nil, "Failed to create video input: \(error.localizedDescription)")
            return
        }
        
        // Setup audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            self.audioDevice = audioDevice
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    self.audioInput = audioInput
                }
            } catch {
                // Audio is optional, continue without it
                print("Failed to add audio input: \(error.localizedDescription)")
            }
        }
        
        // Setup video output for preview
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // Don't discard late frames - we need them for the texture
        videoOutput.alwaysDiscardsLateVideoFrames = false
        
        // Use a dedicated queue for video output to avoid blocking the session queue
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
            print("DivineCamera: Video output added successfully")
            
            // Set video orientation to portrait
            if let connection = videoOutput.connection(with: .video) {
                print("DivineCamera: Video connection established")
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // Mirror pixels only for front camera when mirrorFrontCameraOutput is enabled
                // When mirrored here, Flutter doesn't need to apply preview transform
                // When NOT mirrored here, Flutter applies visual transform for selfie preview
                if connection.isVideoMirroringSupported {
                    let isFront = currentLens == .front
                    connection.isVideoMirrored = isFront && mirrorFrontCameraOutput
                }
            }
        } else {
            print("DivineCamera: ERROR - Cannot add video output to session!")
        }
        
        // Setup audio output for recording
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioOutput = audioOutput
            print("DivineCamera: Audio output added successfully")
        } else {
            print("DivineCamera: WARNING - Cannot add audio output to session")
        }
        
        // NOTE: MovieOutput is intentionally NOT added here during initialization.
        // AVCaptureMovieFileOutput conflicts with AVCaptureVideoDataOutput on some devices,
        // causing the video data output delegate to not receive frames.
        // MovieOutput will be added dynamically when recording starts and removed when it stops.
        
        session.commitConfiguration()
        
        // Get camera properties
        updateCameraProperties(device: videoDevice)
        
        // Start session first so frames start flowing
        session.startRunning()
        self.captureSession = session
        
        // Debug: Check session and connection status
        print("DivineCamera: Session running: \(session.isRunning)")
        if let connection = self.videoOutput?.connection(with: .video) {
            print("DivineCamera: Video connection active: \(connection.isActive), enabled: \(connection.isEnabled)")
        } else {
            print("DivineCamera: ERROR - No video connection available!")
        }
        
        // Check connection status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let connection = self?.videoOutput?.connection(with: .video) {
                print("DivineCamera: After 0.5s - Video connection active: \(connection.isActive), enabled: \(connection.isEnabled)")
            }
            print("DivineCamera: After 0.5s - pixelBufferRef is nil: \(self?.pixelBufferRef == nil)")
        }
        
        // Register texture after session is running
        textureId = textureRegistry.register(self)
        print("DivineCamera: Registered texture with ID: \(textureId)")
        
        // Pre-warm AVAssetWriter in background to avoid lag on first recording
        self.preWarmAssetWriter()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var state = self.getCameraState()
            state["textureId"] = self.textureId
            print("DivineCamera: Returning state with textureId: \(self.textureId)")
            completion(state, nil)
        }
    }
    
    /// Pre-warms the AVAssetWriter to avoid cold-start lag on first recording.
    /// This loads the video encoder framework into memory.
    private func preWarmAssetWriter() {
        DispatchQueue.global(qos: .background).async {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("prewarm.mp4")
            try? FileManager.default.removeItem(at: tempURL)
            
            do {
                let writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1080,
                    AVVideoHeightKey: 1920
                ]
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
                
                // Start and immediately cancel - this loads the encoder
                writer.startWriting()
                writer.cancelWriting()
                
                try? FileManager.default.removeItem(at: tempURL)
                print("DivineCamera: AVAssetWriter pre-warmed successfully")
            } catch {
                print("DivineCamera: Pre-warm failed (non-critical): \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates camera properties from the device.
    private func updateCameraProperties(device: AVCaptureDevice) {
        minZoom = 1.0
        maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        currentZoom = device.videoZoomFactor
        // Front camera has "flash" via screen brightness when feature is enabled
        hasFlash = device.hasFlash || (screenFlashFeatureEnabled && currentLens == .front)
        isFocusPointSupported = device.isFocusPointOfInterestSupported
        isExposurePointSupported = device.isExposurePointOfInterestSupported
        
        // Calculate aspect ratio from the active format dimensions
        // This is the actual camera sensor output size
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        // dimensions.width is the longer side (landscape), height is shorter
        // For portrait mode, we swap to get 9:16 ratio
        aspectRatio = CGFloat(dimensions.height) / CGFloat(dimensions.width)
        print("Camera aspect ratio (portrait): \(aspectRatio) from dimensions: \(dimensions.height)x\(dimensions.width)")
    }
    
    /// Switches to a different camera lens.
    func switchCamera(lens: String, completion: @escaping ([String: Any]?, String?) -> Void) {
        // Disable screen flash and auto-flash when switching cameras
        disableScreenFlash()
        disableAutoFlashTorch()
        isAutoFlashMode = false
        
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else {
                completion(nil, "Session not available")
                return
            }
            
            let newPosition: AVCaptureDevice.Position = lens == "front" ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                completion(nil, "No camera available for position")
                return
            }
            
            session.beginConfiguration()
            
            // Remove old input
            if let oldInput = self.videoInput {
                session.removeInput(oldInput)
            }
            
            // Add new input
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.videoInput = newInput
                    self.videoDevice = newDevice
                    self.currentLens = newPosition
                    self.updateCameraProperties(device: newDevice)
                    
                    // Update orientation and mirroring based on settings
                    if let videoConnection = self.videoOutput?.connection(with: .video) {
                        if videoConnection.isVideoOrientationSupported {
                            videoConnection.videoOrientation = .portrait
                        }
                        // Mirror pixels for front camera when mirrorFrontCameraOutput is enabled
                        let isFront = newPosition == .front
                        if videoConnection.isVideoMirroringSupported {
                            videoConnection.isVideoMirrored = isFront && self.mirrorFrontCameraOutput
                        }
                    }
                }
            } catch {
                // Re-add old input if failed
                if let oldInput = self.videoInput {
                    session.addInput(oldInput)
                }
                session.commitConfiguration()
                completion(nil, "Failed to switch camera: \(error.localizedDescription)")
                return
            }
            
            session.commitConfiguration()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                completion(self.getCameraState(), nil)
            }
        }
    }
    
    /// Sets the flash mode.
    /// For front camera with torch mode, maximizes screen brightness instead.
    /// For "auto" mode, brightness will be checked once when recording starts.
    func setFlashMode(mode: String) -> Bool {
        guard let device = videoDevice else { return false }
        
        print("DivineCamera: Setting flash mode: \(mode) (currentLens: \(currentLens == .front ? "front" : "back"))")
        
        // Handle screen brightness for front camera "torch" mode
        if currentLens == .front {
            if mode == "torch" {
                enableScreenFlash()
                currentTorchMode = .on
                isAutoFlashMode = false
                return true
            } else if mode == "auto" {
                // Auto mode for front camera - will check brightness when recording starts
                disableScreenFlash()
                currentTorchMode = .off
                isAutoFlashMode = true
                currentFlashMode = .auto
                print("DivineCamera: Auto flash mode enabled for front camera")
                return true
            } else {
                disableScreenFlash()
                isAutoFlashMode = false
            }
        }
        
        do {
            try device.lockForConfiguration()
            
            switch mode {
            case "off":
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                currentFlashMode = .off
                currentTorchMode = .off
                isAutoFlashMode = false
                autoFlashTorchEnabled = false
                
            case "auto":
                // Auto mode - will check brightness when recording starts
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                currentTorchMode = .off
                isAutoFlashMode = true
                autoFlashTorchEnabled = false
                currentFlashMode = .auto
                print("DivineCamera: Auto flash mode enabled - will check brightness when recording starts")
                
            case "on":
                currentFlashMode = .on
                isAutoFlashMode = false
                
            case "torch":
                if device.isTorchModeSupported(.on) {
                    device.torchMode = .on
                }
                currentTorchMode = .on
                isAutoFlashMode = false
                
            default:
                break
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("DivineCamera: Failed to set flash mode: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Enables screen flash by setting brightness to maximum (for front camera).
    private func enableScreenFlash() {
        guard screenFlashFeatureEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Save original brightness if not already saved
            if self.originalBrightness == nil {
                self.originalBrightness = UIScreen.main.brightness
            }
            // Set brightness to maximum (1.0 = 100%)
            UIScreen.main.brightness = 1.0
        }
    }
    
    /// Disables screen flash by restoring original brightness.
    private func disableScreenFlash() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let brightness = self.originalBrightness {
                UIScreen.main.brightness = brightness
                self.originalBrightness = nil
                print("DivineCamera: Screen flash disabled (brightness restored)")
            }
        }
    }
    
    /// Checks if the current environment is dark based on camera exposure values.
    /// Uses ISO and exposure duration as indicators (same logic as Android).
    /// Front camera has lower thresholds since screen flash is less intrusive.
    private func isEnvironmentDark() -> Bool {
        guard let device = videoDevice else { return false }
        
        let isoThreshold = currentLens == .front ? frontCameraIsoThreshold : backCameraIsoThreshold
        let exposureThreshold = currentLens == .front ? frontCameraExposureThreshold : backCameraExposureThreshold
        
        let currentISO = device.iso
        let currentExposure = Float(CMTimeGetSeconds(device.exposureDuration))
        
        // If ISO is high OR exposure time is long, it's dark (same as Android)
        let isDark = currentISO >= isoThreshold || currentExposure >= exposureThreshold
        
        print("DivineCamera: Auto flash: ISO=\(currentISO) (threshold=\(isoThreshold)), " +
              "ExposureTime=\(currentExposure * 1000)ms (threshold=\(exposureThreshold * 1000)ms) -> isDark=\(isDark)")
        return isDark
    }
    
    /// Checks the current exposure values and enables auto-flash if needed.
    /// Called when recording starts.
    private func checkAndEnableAutoFlash() {
        guard isAutoFlashMode else { return }
        
        if isEnvironmentDark() {
            print("DivineCamera: Auto flash: Dark environment detected - enabling flash")
            enableAutoFlashTorch()
        } else {
            print("DivineCamera: Auto flash: Bright environment - flash not needed")
        }
    }
    
    /// Enables torch/screen flash for auto flash mode.
    private func enableAutoFlashTorch() {
        if currentLens == .front {
            autoFlashTorchEnabled = true
            enableScreenFlash()
            print("DivineCamera: Auto flash: Screen flash enabled for front camera")
        } else {
            guard let device = videoDevice else {
                print("DivineCamera: Auto flash: No video device")
                return
            }
            guard device.hasTorch else {
                print("DivineCamera: Auto flash: Device has no torch")
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isTorchModeSupported(.on) {
                    device.torchMode = .on
                    autoFlashTorchEnabled = true
                    print("DivineCamera: Auto flash: Torch enabled for back camera")
                } else {
                    print("DivineCamera: Auto flash: Torch mode .on not supported")
                }
                device.unlockForConfiguration()
            } catch {
                print("DivineCamera: Auto flash: Failed to enable torch: \(error.localizedDescription)")
            }
        }
    }
    
    /// Disables torch/screen flash if it was enabled by auto flash mode.
    /// Called when recording stops.
    private func disableAutoFlashTorch() {
        // Always try to turn off torch for back camera, regardless of autoFlashTorchEnabled state
        // This ensures torch doesn't stay on if state got out of sync
        if currentLens == .back {
            if let device = videoDevice, device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    if device.torchMode != .off && device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                        print("DivineCamera: Auto flash: Torch disabled for back camera")
                    }
                    device.unlockForConfiguration()
                } catch {
                    print("DivineCamera: Auto flash: Failed to disable torch: \(error.localizedDescription)")
                }
            }
        } else if autoFlashTorchEnabled {
            disableScreenFlash()
        }
        
        autoFlashTorchEnabled = false
    }
    
    /// Sets the focus point in normalized coordinates (0.0-1.0).
    func setFocusPoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice, device.isFocusPointOfInterestSupported else {
            return false
        }
        
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = CGPoint(x: x, y: y)
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    /// Sets the exposure point in normalized coordinates (0.0-1.0).
    func setExposurePoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice, device.isExposurePointOfInterestSupported else {
            return false
        }
        
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = CGPoint(x: x, y: y)
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    /// Sets the zoom level.
    func setZoomLevel(level: CGFloat) -> Bool {
        guard let device = videoDevice else { return false }
        
        let clampedLevel = max(minZoom, min(level, maxZoom))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedLevel
            device.unlockForConfiguration()
            currentZoom = clampedLevel
            return true
        } catch {
            return false
        }
    }
    
    /// Starts video recording using AVAssetWriter.
    /// - Parameters:
    ///   - maxDurationMs: Optional maximum duration in milliseconds. Recording stops automatically when reached.
    ///   - useCache: If true, saves video to temporary directory. If false, saves to documents directory (permanent).
    ///   - outputDirectory: If provided, saves video to this directory (overrides useCache when false).
    ///   - completion: Callback with error message if failed, nil if successful.
    func startRecording(maxDurationMs: Int?, useCache: Bool = true, outputDirectory: String? = nil, completion: @escaping (String?) -> Void) {
        if isRecording {
            completion("Already recording")
            return
        }
        
        self.maxDurationMs = maxDurationMs
        
        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create output file - use cache, provided directory, or default to documents directory
            let outputDir: URL
            if let customDir = outputDirectory {
                outputDir = URL(fileURLWithPath: customDir)
            } else if useCache {
                outputDir = FileManager.default.temporaryDirectory
            } else {
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                outputDir = paths[0]
            }
            // Use milliseconds timestamp for shorter, sortable, and unique filenames
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let outputURL = outputDir.appendingPathComponent("VID_\(timestamp).mp4")
            self.currentRecordingURL = outputURL
            
            // Remove existing file if any
            try? FileManager.default.removeItem(at: outputURL)
            
            // Setup AVAssetWriter
            do {
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                
                // Get video dimensions from the current format
                guard let device = self.videoDevice else {
                    DispatchQueue.main.async { completion("Video device not available") }
                    return
                }
                
                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                // The video connection is set to .portrait orientation, so frames come in portrait
                // dimensions.width is the longer side (1920), dimensions.height is shorter (1080)
                // After portrait orientation, the frame is 1080 wide x 1920 tall
                let videoWidth = Int(dimensions.height)  // 1080 (portrait width)
                let videoHeight = Int(dimensions.width)  // 1920 (portrait height)
                
                // Video input settings
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: videoWidth,
                    AVVideoHeightKey: videoHeight,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 6000000,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]
                
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                
                // Create pixel buffer adaptor - use the actual frame dimensions (before portrait rotation)
                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: dimensions.height,  // Portrait width
                    kCVPixelBufferHeightKey as String: dimensions.width   // Portrait height
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )
                
                // Audio input settings
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 64000
                ]
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
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
                
                // Start writing
                writer.startWriting()
                
                self.isRecording = true
                self.isWriterSessionStarted = false  // Will be set to true when first frame is received
                self.recordingStartTime = Date()
                
                // Check and enable auto-flash if needed
                self.checkAndEnableAutoFlash()
                
                print("DivineCamera: Recording started to \(outputURL.path)")
                
                // Schedule max duration timer if specified
                if let maxMs = maxDurationMs, maxMs > 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.maxDurationTimer = Timer.scheduledTimer(withTimeInterval: Double(maxMs) / 1000.0, repeats: false) { [weak self] _ in
                            self?.autoStopRecording()
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(nil)
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion("Failed to create asset writer: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Automatically stops recording when max duration is reached.
    private func autoStopRecording() {
        guard isRecording else { return }
        
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        stopRecording { [weak self] result, error in
            // Send auto-stop event through method channel
            if let result = result {
                self?.sendAutoStopEvent(result: result)
            }
        }
    }
    
    /// Sends auto-stop event to Flutter.
    private func sendAutoStopEvent(result: [String: Any]) {
        // This will be handled by the plugin via a callback or event channel
        NotificationCenter.default.post(
            name: NSNotification.Name("DivineCameraAutoStop"),
            object: nil,
            userInfo: result
        )
    }
    
    /// Stops video recording and returns the result.
    func stopRecording(completion: @escaping ([String: Any]?, String?) -> Void) {
        guard isRecording, let writer = assetWriter else {
            completion(nil, "Not recording")
            return
        }
        
        // Cancel max duration timer if running
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        // Disable auto-flash torch if it was enabled
        disableAutoFlashTorch()
        
        isRecording = false
        
        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()
            
            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        // Calculate duration
                        let duration: Int
                        if let startTime = self.recordingStartTime {
                            duration = Int(Date().timeIntervalSince(startTime) * 1000)
                        } else {
                            duration = 0
                        }
                        
                        // Get video dimensions
                        guard let outputURL = self.currentRecordingURL else {
                            completion(nil, "Output URL not available")
                            return
                        }
                        
                        var width: Int = 1920
                        var height: Int = 1080
                        
                        let asset = AVAsset(url: outputURL)
                        if let track = asset.tracks(withMediaType: .video).first {
                            let size = track.naturalSize.applying(track.preferredTransform)
                            width = Int(abs(size.width))
                            height = Int(abs(size.height))
                        }
                        
                        let result: [String: Any] = [
                            "filePath": outputURL.path,
                            "durationMs": duration,
                            "width": width,
                            "height": height
                        ]
                        
                        print("DivineCamera: Recording completed - \(outputURL.path)")
                        completion(result, nil)
                    } else {
                        completion(nil, "Recording failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                    }
                    
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
    
    /// Pauses the camera preview.
    func pausePreview() {
        disableScreenFlash()
        isPaused = true
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    /// Resumes the camera preview.
    func resumePreview(completion: @escaping ([String: Any]?, String?) -> Void) {
        isPaused = false
        
        // Re-enable screen flash if front camera torch mode was active
        if currentLens == .front && currentTorchMode == .on {
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
    
    /// Gets the current camera state as a dictionary.
    func getCameraState() -> [String: Any] {
        return [
            "isInitialized": captureSession != nil,
            "isRecording": isRecording,
            "flashMode": getFlashModeString(),
            "lens": currentLens == .front ? "front" : "back",
            "zoomLevel": Double(currentZoom),
            "minZoomLevel": Double(minZoom),
            "maxZoomLevel": Double(maxZoom),
            "aspectRatio": Double(aspectRatio),
            "hasFlash": hasFlash,
            "hasFrontCamera": hasFrontCamera,
            "hasBackCamera": hasBackCamera,
            "isFocusPointSupported": isFocusPointSupported,
            "isExposurePointSupported": isExposurePointSupported,
            "textureId": textureId
        ]
    }
    
    /// Gets the current flash mode as a string.
    private func getFlashModeString() -> String {
        if currentTorchMode == .on {
            return "torch"
        }
        switch currentFlashMode {
        case .off:
            return "off"
        case .auto:
            return "auto"
        case .on:
            return "on"
        @unknown default:
            return "off"
        }
    }
    
    /// Releases all camera resources.
    func release() {
        // Restore screen brightness if screen flash was enabled
        disableScreenFlash()
        // Disable auto-flash if it was enabled
        disableAutoFlashTorch()
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop recording if in progress
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
            
            // Cleanup asset writer if recording
            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil
            self.pixelBufferAdaptor = nil
            
            if self.textureId >= 0 {
                self.textureRegistry.unregisterTexture(self.textureId)
                self.textureId = -1
            }
            
            // Thread-safe release of the sample buffer (which also releases the pixel buffer)
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
            print("DivineCamera: copyPixelBuffer called but pixelBufferRef is nil")
            return nil
        }
        return Unmanaged.passRetained(pixelBuffer)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isPaused else { return }
        
        // Handle video output
        if output == videoOutput {
            // Get pixel buffer from sample buffer
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("DivineCamera: Could not get pixel buffer from sample buffer")
                return
            }
            
            // Thread-safe update of the pixel buffer for preview
            pixelBufferLock.lock()
            let isFirstFrame = latestSampleBuffer == nil
            latestSampleBuffer = sampleBuffer
            pixelBufferRef = pixelBuffer
            pixelBufferLock.unlock()
            
            if isFirstFrame {
                print("DivineCamera: First frame received! Pixel buffer dimensions: \(CVPixelBufferGetWidth(pixelBuffer))x\(CVPixelBufferGetHeight(pixelBuffer))")
            }
            
            // Notify Flutter on main thread that a new frame is available
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.textureId >= 0 else { return }
                self.textureRegistry.textureFrameAvailable(self.textureId)
            }
            
            // Write video frame to asset writer if recording
            if isRecording, let writer = assetWriter, let videoInput = videoWriterInput, let adaptor = pixelBufferAdaptor {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                // Start session on first frame
                if !isWriterSessionStarted && writer.status == .writing {
                    writer.startSession(atSourceTime: timestamp)
                    isWriterSessionStarted = true
                    print("DivineCamera: Writer session started at \(timestamp.seconds)")
                }
                
                if writer.status == .writing && videoInput.isReadyForMoreMediaData {
                    adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                }
            }
        }
        // Handle audio output
        else if output == audioOutput {
            if isRecording, let writer = assetWriter, let audioInput = audioWriterInput {
                // Only append audio after session has started
                if isWriterSessionStarted && writer.status == .writing && audioInput.isReadyForMoreMediaData {
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
