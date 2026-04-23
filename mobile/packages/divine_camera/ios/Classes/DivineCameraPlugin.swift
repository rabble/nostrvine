// ABOUTME: Main Flutter plugin entry point for iOS camera operations
// ABOUTME: Handles method channel communication and delegates to CameraController

import Flutter
import UIKit
import AVFoundation

public class DivineCameraPlugin: NSObject, FlutterPlugin {
    private var cameraController: CameraController?
    private var textureRegistry: FlutterTextureRegistry?
    private var messenger: FlutterBinaryMessenger?
    private var methodChannel: FlutterMethodChannel?
    private var volumeKeyHandler: VolumeKeyHandler?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "divine_camera", binaryMessenger: registrar.messenger())
        let instance = DivineCameraPlugin()
        instance.textureRegistry = registrar.textures()
        instance.messenger = registrar.messenger()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Listen for auto-stop events from CameraController
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.handleAutoStop(_:)),
            name: NSNotification.Name("DivineCameraAutoStop"),
            object: nil
        )

        // Pre-warm the AV media stack on a background queue at plugin
        // registration (very early in app launch, before the user can reach
        // the camera page).
        //
        // Why here and not in CameraController.setupCamera(): doing dlopen()
        // on a background queue WHILE Main is wiring up the camera page
        // causes dyld to post process-wide image-load notifications that
        // block Main on its next lazy symbol bind. That was the source of
        // the ~1s freeze on first camera open.
        //
        // Doing the pre-warm here, far away from camera open, gives dyld
        // and mediaserverd time to settle. By the time the user reaches
        // the camera, AudioToolbox + VideoToolbox are loaded and Main is
        // not blocked.
        preWarmFrameworks()
    }

    /// Loads AudioToolbox + VideoToolbox + the AVAudioSession machinery off
    /// the main thread at plugin registration. Idempotent — safe to call
    /// once per process.
    private static func preWarmFrameworks() {
        DispatchQueue.global(qos: .utility).async {
            // 1. AudioToolbox + AVAudioSession + mediaserverd XPC roundtrip.
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .allowBluetoothA2DP]
                )
                // Do NOT call setActive(true) — that would steal audio focus
                // from anything currently playing. setCategory alone triggers
                // the dlopen.
                print("DivineCamera: AVAudioSession category configured")
            } catch {
                print("DivineCamera: AVAudioSession config failed: \(error.localizedDescription)")
            }
            _ = AVCaptureDevice.default(for: .audio)

            // 2. VideoToolbox via a throwaway AVAssetWriter.
            // startWriting() loads the H.264 encoder; cancelWriting()
            // releases it immediately so we don't hold any encoder resources.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("divine_av_prewarm.mp4")
            try? FileManager.default.removeItem(at: tempURL)
            do {
                let writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1080,
                    AVVideoHeightKey: 1920,
                ]
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
                writer.startWriting()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: tempURL)
                print("DivineCamera: VideoToolbox pre-warmed via AVAssetWriter")
            } catch {
                print("DivineCamera: VideoToolbox pre-warm failed: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleAutoStop(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        
        // Invoke method channel to notify Flutter of auto-stop
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onRecordingAutoStopped", arguments: userInfo)
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "initializeCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let lens = args["lens"] as? String ?? "back"
            let videoQuality = args["videoQuality"] as? String ?? "fhd"
            let enableScreenFlash = args["enableScreenFlash"] as? Bool ?? true
            let mirrorFrontCameraOutput = args["mirrorFrontCameraOutput"] as? Bool ?? true
            let enableAutoLensSwitch = args["enableAutoLensSwitch"] as? Bool ?? true
            initializeCamera(lens: lens, videoQuality: videoQuality, enableScreenFlash: enableScreenFlash, mirrorFrontCameraOutput: mirrorFrontCameraOutput, enableAutoLensSwitch: enableAutoLensSwitch, result: result)
            
        case "disposeCamera":
            disposeCamera(result: result)
            
        case "setFlashMode":
            let args = call.arguments as? [String: Any] ?? [:]
            let mode = args["mode"] as? String ?? "off"
            setFlashMode(mode: mode, result: result)
            
        case "setFocusPoint":
            let args = call.arguments as? [String: Any] ?? [:]
            let x = args["x"] as? Double ?? 0.5
            let y = args["y"] as? Double ?? 0.5
            setFocusPoint(x: x, y: y, result: result)
            
        case "setExposurePoint":
            let args = call.arguments as? [String: Any] ?? [:]
            let x = args["x"] as? Double ?? 0.5
            let y = args["y"] as? Double ?? 0.5
            setExposurePoint(x: x, y: y, result: result)
            
        case "cancelFocusAndMetering":
            cancelFocusAndMetering(result: result)
            
        case "setZoomLevel":
            let args = call.arguments as? [String: Any] ?? [:]
            let level = args["level"] as? Double ?? 1.0
            setZoomLevel(level: level, result: result)
            
        case "switchCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let lens = args["lens"] as? String ?? "back"
            switchCamera(lens: lens, result: result)
            
        case "startRecording":
            let args = call.arguments as? [String: Any] ?? [:]
            let maxDurationMs = args["maxDurationMs"] as? Int
            let useCache = args["useCache"] as? Bool ?? true
            let outputDirectory = args["outputDirectory"] as? String
            startRecording(maxDurationMs: maxDurationMs, useCache: useCache, outputDirectory: outputDirectory, result: result)
            
        case "stopRecording":
            stopRecording(result: result)
            
        case "pausePreview":
            pausePreview(result: result)
            
        case "resumePreview":
            resumePreview(result: result)
            
        case "getCameraState":
            getCameraState(result: result)
            
        case "setRemoteRecordControlEnabled":
            let args = call.arguments as? [String: Any] ?? [:]
            let enabled = args["enabled"] as? Bool ?? false
            setRemoteRecordControlEnabled(enabled: enabled, result: result)
            
        case "setVolumeKeysEnabled":
            let args = call.arguments as? [String: Any] ?? [:]
            let enabled = args["enabled"] as? Bool ?? true
            setVolumeKeysEnabled(enabled: enabled, result: result)
            
        case "listAudioDevices":
            listAudioDevices(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeCamera(lens: String, videoQuality: String, enableScreenFlash: Bool, mirrorFrontCameraOutput: Bool, enableAutoLensSwitch: Bool, result: @escaping FlutterResult) {
        guard let registry = textureRegistry else {
            result(FlutterError(code: "NO_REGISTRY", message: "Texture registry not available", details: nil))
            return
        }
        
        cameraController?.release()
        cameraController = CameraController(textureRegistry: registry)
        
        cameraController?.initialize(lens: lens, videoQuality: videoQuality, enableScreenFlash: enableScreenFlash, mirrorFrontCameraOutput: mirrorFrontCameraOutput, enableAutoLensSwitch: enableAutoLensSwitch) { [weak self] state, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "INIT_ERROR", message: error, details: nil))
                } else {
                    result(state)
                }
            }
        }
    }
    
    private func disposeCamera(result: @escaping FlutterResult) {
        volumeKeyHandler?.release()
        volumeKeyHandler = nil
        cameraController?.release()
        cameraController = nil
        result(nil)
    }
    
    private func setRemoteRecordControlEnabled(enabled: Bool, result: @escaping FlutterResult) {
        if enabled {
            if volumeKeyHandler == nil {
                volumeKeyHandler = VolumeKeyHandler { [weak self] triggerType in
                    // Send trigger event to Flutter on main thread
                    DispatchQueue.main.async {
                        self?.methodChannel?.invokeMethod("onRemoteRecordTrigger", arguments: triggerType)
                    }
                }
            }
            let success = volumeKeyHandler?.enable() ?? false
            result(success)
        } else {
            volumeKeyHandler?.disable()
            result(true)
        }
    }
    
    private func setVolumeKeysEnabled(enabled: Bool, result: @escaping FlutterResult) {
        volumeKeyHandler?.setVolumeKeysEnabled(enabled)
        result(true)
    }
    
    private func setFlashMode(mode: String, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        let success = controller.setFlashMode(mode: mode)
        result(success)
    }
    
    private func setFocusPoint(x: Double, y: Double, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        let success = controller.setFocusPoint(x: CGFloat(x), y: CGFloat(y))
        result(success)
    }
    
    private func setExposurePoint(x: Double, y: Double, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        let success = controller.setExposurePoint(x: CGFloat(x), y: CGFloat(y))
        result(success)
    }
    
    private func cancelFocusAndMetering(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        let success = controller.cancelFocusAndMetering()
        result(success)
    }
    
    private func setZoomLevel(level: Double, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        let success = controller.setZoomLevel(level: CGFloat(level))
        result(success)
    }
    
    private func switchCamera(lens: String, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        
        // Suppress Bluetooth triggers during camera switch.
        // iOS re-evaluates audio routing on AVCaptureSession reconfiguration,
        // which can cause connected Bluetooth devices (Apple Watch, AirPods)
        // to send spurious play/pause events that would restart recording.
        volumeKeyHandler?.suppressTemporarily(forSeconds: 3.0)
        
        controller.switchCamera(lens: lens) { state, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "SWITCH_ERROR", message: error, details: nil))
                } else {
                    result(state)
                }
            }
        }
    }
    
    private func startRecording(maxDurationMs: Int?, useCache: Bool, outputDirectory: String?, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        
        controller.startRecording(maxDurationMs: maxDurationMs, useCache: useCache, outputDirectory: outputDirectory) { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "RECORD_START_ERROR", message: error, details: nil))
                } else {
                    result(nil)
                }
            }
        }
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        
        controller.stopRecording { recordingResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "RECORD_STOP_ERROR", message: error, details: nil))
                } else {
                    result(recordingResult)
                }
            }
        }
    }
    
    private func pausePreview(result: @escaping FlutterResult) {
        cameraController?.pausePreview()
        result(nil)
    }
    
    private func resumePreview(result: @escaping FlutterResult) {
        cameraController?.resumePreview { state, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "RESUME_ERROR", message: error, details: nil))
                } else {
                    result(state)
                }
            }
        }
    }
    
    private func getCameraState(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera not initialized", details: nil))
            return
        }
        result(controller.getCameraState())
    }
    
    private func listAudioDevices(result: @escaping FlutterResult) {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified
        )
        let devices: [[String: String]] = discoverySession.devices.map { device in
            [
                "id": device.uniqueID,
                "name": device.localizedName,
            ]
        }
        result(devices)
    }
}
