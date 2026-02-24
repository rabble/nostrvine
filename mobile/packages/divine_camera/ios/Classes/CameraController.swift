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
    
    // Multi-lens support
    private var hasUltraWideCamera: Bool = false
    private var hasTelephotoCamera: Bool = false
    private var hasMacroCamera: Bool = false
    private var hasFrontUltraWideCamera: Bool = false
    
    // Current lens type (more granular than just position)
    private var currentLensType: String = "back"
    
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    private var recordingCompletion: (([String: Any]?, String?) -> Void)?
    private var maxDurationTimer: Timer?
    private var maxDurationMs: Int?
    private var isWriterSessionStarted: Bool = false
    
    /// Completion handler for camera switch - called when first frame from new camera arrives
    private var switchCameraCompletion: (([String: Any]?, String?) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "com.divine_camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.divine_camera.videoOutput")
    
    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
        checkCameraAvailability()
    }
    
    /// Checks which cameras are available on the device.
    private func checkCameraAvailability() {
        // Check front camera
        let frontDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        hasFrontCamera = !frontDiscoverySession.devices.isEmpty
        
        // Check front ultra-wide camera (iOS 13+, available on some iPads)
        if #available(iOS 13.0, *) {
            let frontUltraWideDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .front
            )
            hasFrontUltraWideCamera = !frontUltraWideDiscoverySession.devices.isEmpty
        }
        
        // Check back cameras
        let backDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        hasBackCamera = !backDiscoverySession.devices.isEmpty
        
        // Check ultra-wide camera (iOS 13+)
        if #available(iOS 13.0, *) {
            let ultraWideDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .back
            )
            hasUltraWideCamera = !ultraWideDiscoverySession.devices.isEmpty
        }
        
        // Check telephoto camera
        let telephotoDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        hasTelephotoCamera = !telephotoDiscoverySession.devices.isEmpty
        
        // Check for macro capability (iOS 15+ on devices with ultra-wide lens capable of macro)
        // Macro is typically available on ultra-wide lens on iPhone 13 Pro and later
        if #available(iOS 15.0, *) {
            if hasUltraWideCamera {
                // On iOS 15+, devices with ultra-wide can support macro mode
                // The ultra-wide lens on Pro models has minimum focus distance for macro
                if let ultraWideDevice = AVCaptureDevice.default(
                    .builtInUltraWideCamera,
                    for: .video,
                    position: .back
                ) {
                    // Check if the ultra-wide supports close focus (macro)
                    // Devices supporting macro typically have minimum focus distance < 0.5m
                    let format = ultraWideDevice.activeFormat
                    if format.autoFocusSystem == .phaseDetection || format.autoFocusSystem == .contrastDetection {
                        // Ultra-wide with autofocus can typically do macro
                        hasMacroCamera = true
                    }
                }
            }
        }
        
        print("[DivineCameraController] Camera availability: front=\(hasFrontCamera), " +
              "frontUltraWide=\(hasFrontUltraWideCamera), back=\(hasBackCamera), " +
              "ultraWide=\(hasUltraWideCamera), telephoto=\(hasTelephotoCamera), macro=\(hasMacroCamera)")
    }
    
    /// Gets metadata for the currently active camera lens.
    private func getCurrentLensMetadata() -> [String: Any]? {
        guard let device = videoDevice else {
            return nil
        }
        return extractCameraMetadata(device: device, lensType: currentLensType)
    }
    
    /// Extracts metadata from an AVCaptureDevice.
    /// For C2PA compliance, only values that iOS actually provides are included.
    /// Estimated values (focalLength, sensorSize, minFocusDistance) are left as nil.
    private func extractCameraMetadata(device: AVCaptureDevice, lensType: String) -> [String: Any] {
        let format = device.activeFormat
        let formatDescription = format.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        
        // iOS doesn't expose physical focal length directly
        // This would need to come from EXIF data of captured images
        let focalLength: Double? = nil
        
        // Aperture IS available on iOS via lensAperture property
        let aperture: Double = Double(device.lensAperture)
        
        var fieldOfView: Double? = nil
        
        // Field of view is available on the format
        let fov = format.videoFieldOfView
        if fov > 0 {
            fieldOfView = Double(fov)
        }
        
        // Try to get more accurate field of view from device formats
        if #available(iOS 13.0, *) {
            // Get geometric distortion corrected field of view if available
            if let videoFormat = device.formats.first(where: { $0 === format }) {
                fieldOfView = Double(videoFormat.videoFieldOfView)
            }
        }
        
        // Min focus distance
        // Note: iOS doesn't expose actual minimum focus distance values.
        // For C2PA compliance, we leave this as nil rather than providing estimates.
        let minFocusDistance: Double? = nil
        
        // Optical stabilization
        let hasOpticalStabilization = device.activeFormat.isVideoStabilizationModeSupported(.cinematic) ||
                                      device.activeFormat.isVideoStabilizationModeSupported(.standard)
        
        // Sensor size - iOS doesn't expose actual sensor dimensions
        let sensorWidth: Double? = nil
        let sensorHeight: Double? = nil
        
        // Calculate 35mm equivalent focal length from field of view
        // This IS accurate as it's mathematically derived from FOV which iOS provides.
        // Formula: FOV = 2 * arctan(sensor_diagonal / (2 * focal_length))
        // For 35mm film: diagonal = 43.27mm
        // Therefore: focal_length_35mm = 43.27 / (2 * tan(FOV/2))
        var focalLengthEquivalent35mm: Double? = nil
        if let fov = fieldOfView, fov > 0 {
            let fovRadians = fov * .pi / 180.0
            let equivalent = 43.27 / (2.0 * tan(fovRadians / 2.0))
            focalLengthEquivalent35mm = equivalent
        }
        
        // Check if this is a multi-camera logical device
        var isLogicalCamera = false
        var physicalCameraIds: [String] = []
        if #available(iOS 13.0, *) {
            let physicalDevices = device.constituentDevices
            isLogicalCamera = physicalDevices.count > 1
            physicalCameraIds = physicalDevices.map { $0.uniqueID }
        }
        
        // Camera unique identifier
        let cameraId = device.uniqueID
        
        // Exposure duration in seconds (live value)
        let exposureDuration = CMTimeGetSeconds(device.exposureDuration)
        
        // ISO sensitivity (live value)
        let iso = Double(device.iso)
        
        return [
            "lensType": lensType,
            "cameraId": cameraId,
            "focalLength": focalLength as Any,
            "focalLengthEquivalent35mm": focalLengthEquivalent35mm as Any,
            "aperture": aperture,
            "sensorWidth": sensorWidth as Any,
            "sensorHeight": sensorHeight as Any,
            "pixelArrayWidth": Int(dimensions.width),
            "pixelArrayHeight": Int(dimensions.height),
            "minFocusDistance": minFocusDistance as Any,
            "fieldOfView": fieldOfView as Any,
            "hasOpticalStabilization": hasOpticalStabilization,
            "isLogicalCamera": isLogicalCamera,
            "physicalCameraIds": physicalCameraIds,
            "exposureDuration": exposureDuration,
            "iso": iso
        ]
    }
    
    /// Returns a list of available lens types on this device.
    private func getAvailableLenses() -> [String] {
        var lenses: [String] = []
        if hasFrontCamera { lenses.append("front") }
        if hasFrontUltraWideCamera { lenses.append("frontUltraWide") }
        if hasBackCamera { lenses.append("back") }
        if hasUltraWideCamera { lenses.append("ultraWide") }
        if hasTelephotoCamera { lenses.append("telephoto") }
        if hasMacroCamera { lenses.append("macro") }
        return lenses
    }
    
    /// Gets the AVCaptureDevice for the specified lens type.
    private func getDeviceForLensType(_ lensType: String) -> AVCaptureDevice? {
        switch lensType {
        case "front":
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        case "frontUltraWide":
            if #available(iOS 13.0, *) {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .front)
            }
            return nil
        case "back":
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case "ultraWide":
            if #available(iOS 13.0, *) {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            }
            return nil
        case "telephoto":
            return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        case "macro":
            // Macro uses ultra-wide lens on iOS
            if #available(iOS 13.0, *) {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            }
            return nil
        default:
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
    }
    
    /// Gets the position for the specified lens type.
    private func getPositionForLensType(_ lensType: String) -> AVCaptureDevice.Position {
        switch lensType {
        case "front", "frontUltraWide":
            return .front
        default:
            return .back
        }
    }
    
    /// Initializes the camera with the specified lens.
    private var videoQualityPreset: AVCaptureSession.Preset = .high
    
    /// Initializes the camera with the specified lens and video quality.
    func initialize(lens: String, videoQuality: String, enableScreenFlash: Bool = true, mirrorFrontCameraOutput: Bool = true, completion: @escaping ([String: Any]?, String?) -> Void) {
        currentLensType = lens
        currentLens = getPositionForLensType(lens)
        screenFlashFeatureEnabled = enableScreenFlash
        self.mirrorFrontCameraOutput = mirrorFrontCameraOutput
        
        // Fallback to available camera if requested lens is not available
        if getDeviceForLensType(currentLensType) == nil {
            // Try back camera first, then front
            if hasBackCamera {
                print("[DivineCameraController] Requested lens \(lens) not available, falling back to back camera")
                currentLensType = "back"
                currentLens = .back
            } else if hasFrontCamera {
                print("[DivineCameraController] Requested lens \(lens) not available, falling back to front camera")
                currentLensType = "front"
                currentLens = .front
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
        // NOTE: We do NOT explicitly configure AVAudioSession here.
        // AVCaptureSession automatically manages the audio session when an
        // audio input device is added below. Explicitly setting .playAndRecord
        // with .allowBluetooth/.allowBluetoothA2DP causes iOS to establish a
        // Bluetooth audio connection, which triggers spurious play/pause events
        // on connected devices (AirPods, Apple Watch) via MPRemoteCommandCenter.
        
        // Create capture session
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Setup video input FIRST (before setting preset)
        guard let videoDevice = getDeviceForLensType(currentLensType) else {
            completion(nil, "No camera available for lens type: \(currentLensType)")
            return
        }
        
        self.videoDevice = videoDevice
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            // Add input before setting preset
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoInput = videoInput
            } else {
                completion(nil, "Cannot add video input")
                return
            }
            
            // Now set preset AFTER adding input - try requested quality with fallback
            let presetsToTry: [AVCaptureSession.Preset] = [
                videoQualityPreset,
                .hd4K3840x2160,
                .hd1920x1080,
                .hd1280x720,
                .high,
                .medium,
                .low
            ]
            
            var presetSet = false
            for preset in presetsToTry {
                if session.canSetSessionPreset(preset) {
                    session.sessionPreset = preset
                    if preset != videoQualityPreset {
                        print("[DivineCameraController] Requested preset not supported, falling back to: \(preset.rawValue)")
                    }
                    presetSet = true
                    break
                }
            }
            
            if !presetSet {
                print("[DivineCameraController] Warning: Could not set any preferred preset")
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
            
            // Update lens type and position
            self.currentLensType = lens
            self.currentLens = self.getPositionForLensType(lens)
            
            guard let newDevice = self.getDeviceForLensType(lens) else {
                completion(nil, "Lens \(lens) is not available on this device")
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
                
                // First try to add input with current preset
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.videoInput = newInput
                    self.videoDevice = newDevice
                    self.updateCameraProperties(device: newDevice)
                } else {
                    // Current preset may not be supported by new camera (e.g., UHD on front camera)
                    // Try fallback presets
                    let fallbackPresets: [AVCaptureSession.Preset] = [
                        .hd4K3840x2160,
                        .hd1920x1080,
                        .hd1280x720,
                        .high,
                        .medium,
                        .low
                    ]
                    
                    var success = false
                    for preset in fallbackPresets {
                        if session.canSetSessionPreset(preset) {
                            session.sessionPreset = preset
                            if session.canAddInput(newInput) {
                                session.addInput(newInput)
                                self.videoInput = newInput
                                self.videoDevice = newDevice
                                self.updateCameraProperties(device: newDevice)
                                print("[DivineCameraController] Camera switch: preset fallback to \(preset.rawValue)")
                                success = true
                                break
                            }
                        }
                    }
                    
                    if !success {
                        // Re-add old input if all fallbacks failed
                        if let oldInput = self.videoInput {
                            session.addInput(oldInput)
                        }
                        session.commitConfiguration()
                        completion(nil, "Cannot add video input for new camera")
                        return
                    }
                }
                
                // Update orientation and mirroring based on settings
                if let videoConnection = self.videoOutput?.connection(with: .video) {
                    if videoConnection.isVideoOrientationSupported {
                        videoConnection.videoOrientation = .portrait
                    }
                    // Mirror pixels for front camera when mirrorFrontCameraOutput is enabled
                    let isFront = newDevice.position == .front
                    if videoConnection.isVideoMirroringSupported {
                        videoConnection.isVideoMirrored = isFront && self.mirrorFrontCameraOutput
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
            
            // Store completion to be called when first frame arrives from new camera.
            // This ensures Flutter gets the new lens state only after the texture
            // already shows a frame from the new camera, preventing mirror glitches.
            self.switchCameraCompletion = { [weak self] state, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    completion(self.getCameraState(), nil)
                }
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
    
    /// Work item for auto-cancel focus timer
    private var focusAutoCancelWorkItem: DispatchWorkItem?
    
    /// Duration in seconds before focus returns to continuous auto-focus (like TikTok)
    private let focusLockDuration: TimeInterval = 3.0
    
    /// Sets the focus point in normalized coordinates (0.0-1.0).
    /// Uses combined focus + exposure + white balance for best results.
    /// Focus is locked for 3 seconds, then returns to continuous auto-focus.
    ///
    /// Note: Input coordinates are in display space (portrait mode).
    /// iOS focusPointOfInterest uses sensor coordinates (landscape),
    /// so we transform: display (x, y) → sensor (y, 1-x) for portrait mode.
    func setFocusPoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice, device.isFocusPointOfInterestSupported else {
            return false
        }
        
        // Cancel any pending auto-cancel timer from previous tap
        focusAutoCancelWorkItem?.cancel()
        
        // Transform display coordinates to sensor coordinates
        // iOS sensor coordinate system is always landscape-oriented:
        // - (0,0) is top-left of sensor (in landscape)
        // - For portrait mode, we need to rotate the coordinates
        // Display (x, y) → Sensor (y, 1-x) for portrait orientation
        let sensorPoint = CGPoint(x: y, y: 1 - x)
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point and trigger one-shot auto-focus
            device.focusPointOfInterest = sensorPoint
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            
            // Also set exposure at the same point for consistent results
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = sensorPoint
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
            
            // Also trigger white balance adjustment (iOS doesn't have point of interest for WB,
            // but setting to auto mode will let it recalculate based on scene)
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            device.unlockForConfiguration()
            
            // Schedule return to continuous auto-focus after focusLockDuration
            let workItem = DispatchWorkItem { [weak self] in
                self?.returnToContinuousAutoFocus()
            }
            focusAutoCancelWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + focusLockDuration, execute: workItem)
            
            return true
        } catch {
            return false
        }
    }
    
    /// Returns focus, exposure, and white balance to continuous auto mode.
    private func returnToContinuousAutoFocus() {
        guard let device = videoDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Return to continuous auto-focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Return to continuous auto-exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Ensure continuous auto white balance (should already be set, but ensure it)
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            device.unlockForConfiguration()
        } catch {
            // Silently fail
        }
    }
    
    /// Sets the exposure point in normalized coordinates (0.0-1.0).
    /// For exposure-only adjustment without changing focus.
    ///
    /// Note: Input coordinates are in display space (portrait mode).
    /// iOS exposurePointOfInterest uses sensor coordinates (landscape),
    /// so we transform: display (x, y) → sensor (y, 1-x) for portrait mode.
    func setExposurePoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice, device.isExposurePointOfInterestSupported else {
            return false
        }
        
        // Transform display coordinates to sensor coordinates
        let sensorPoint = CGPoint(x: y, y: 1 - x)
        
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = sensorPoint
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    /// Cancels any active focus/metering lock and returns to continuous auto-focus.
    /// Call this when you want to reset focus behavior after a tap-to-focus.
    func cancelFocusAndMetering() -> Bool {
        // Cancel any pending auto-cancel timer
        focusAutoCancelWorkItem?.cancel()
        focusAutoCancelWorkItem = nil
        
        guard let device = videoDevice else { return false }
        
        do {
            try device.lockForConfiguration()
            
            // Return to continuous auto-focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Return to continuous auto-exposure
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
            "lens": currentLensType,
            "zoomLevel": Double(currentZoom),
            "minZoomLevel": Double(minZoom),
            "maxZoomLevel": Double(maxZoom),
            "aspectRatio": Double(aspectRatio),
            "hasFlash": hasFlash,
            "hasFrontCamera": hasFrontCamera,
            "hasBackCamera": hasBackCamera,
            "isFocusPointSupported": isFocusPointSupported,
            "isExposurePointSupported": isExposurePointSupported,
            "textureId": textureId,
            "availableLenses": getAvailableLenses(),
            "currentLensMetadata": getCurrentLensMetadata() as Any
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
            
            // Complete camera switch if waiting for first frame from new camera.
            // This is done AFTER textureFrameAvailable so Flutter shows the new frame
            // before receiving the state update with the new lens.
            if let switchCompletion = switchCameraCompletion {
                switchCameraCompletion = nil
                let state = getCameraState()
                switchCompletion(state, nil)
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
