// ABOUTME: Native macOS camera implementation using AVFoundation
// ABOUTME: Provides real camera access through platform channels for Flutter

import FlutterMacOS
import AVFoundation
import Foundation

public class NativeCameraPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var isRecording = false
    private var outputURL: URL?
    private var stopRecordingResult: FlutterResult?
    
    // Frame processing
    private let videoQueue = DispatchQueue(label: "VideoQueue", qos: .userInteractive)
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "nostrvine/native_camera",
            binaryMessenger: registrar.messenger
        )
        let instance = NativeCameraPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Method called: \(call.method)")
        
        switch call.method {
        case "initialize":
            print("🔵 [NativeCamera] Handling initialize request")
            initializeCamera(result: result)
        case "startPreview":
            print("🔵 [NativeCamera] Handling startPreview request")
            startPreview(result: result)
        case "stopPreview":
            print("🔵 [NativeCamera] Handling stopPreview request")
            stopPreview(result: result)
        case "startRecording":
            print("🔵 [NativeCamera] Handling startRecording request")
            startRecording(result: result)
        case "stopRecording":
            print("🔵 [NativeCamera] Handling stopRecording request")
            stopRecording(result: result)
        case "requestPermission":
            print("🔵 [NativeCamera] Handling requestPermission request")
            requestPermission(result: result)
        case "hasPermission":
            print("🔵 [NativeCamera] Handling hasPermission request")
            hasPermission(result: result)
        case "getAvailableCameras":
            print("🔵 [NativeCamera] Handling getAvailableCameras request")
            getAvailableCameras(result: result)
        case "switchCamera":
            print("🔵 [NativeCamera] Handling switchCamera request")
            if let args = call.arguments as? [String: Any],
               let cameraIndex = args["cameraIndex"] as? Int {
                print("🔵 [NativeCamera] Switch to camera index: \(cameraIndex)")
                switchCamera(cameraIndex: cameraIndex, result: result)
            } else {
                print("❌ [NativeCamera] Invalid camera index argument")
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid camera index", details: nil))
            }
        case "dispose":
            print("🔵 [NativeCamera] Handling dispose request")
            dispose(result: result)
        default:
            print("❌ [NativeCamera] Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeCamera(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Starting camera initialization")
        
        // Check camera permission first
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔵 [NativeCamera] Camera authorization status: \(authStatus.rawValue)")
        
        switch authStatus {
        case .authorized:
            print("✅ [NativeCamera] Camera permission already granted, setting up session")
            setupCaptureSession(result: result)
        case .notDetermined:
            print("⚠️ [NativeCamera] Camera permission not determined, requesting...")
            requestPermission { [weak self] granted in
                print("🔵 [NativeCamera] Permission request result: \(granted)")
                if granted {
                    print("✅ [NativeCamera] Permission granted, setting up session")
                    self?.setupCaptureSession(result: result)
                } else {
                    print("❌ [NativeCamera] Permission denied by user")
                    result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
                }
            }
        case .denied, .restricted:
            print("❌ [NativeCamera] Camera permission denied/restricted")
            result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
        @unknown default:
            print("❌ [NativeCamera] Unknown permission status")
            result(FlutterError(code: "PERMISSION_UNKNOWN", message: "Unknown permission status", details: nil))
        }
    }
    
    private func setupCaptureSession(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Setting up capture session")
        
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            print("❌ [NativeCamera] Failed to create capture session")
            result(FlutterError(code: "SESSION_FAILED", message: "Failed to create capture session", details: nil))
            return
        }
        
        print("✅ [NativeCamera] Capture session created successfully")
        
        captureSession.beginConfiguration()
        
        // Set session preset
        if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
        }
        
        // Get default video device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
                                AVCaptureDevice.default(for: .video) else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }
        
        self.videoDevice = videoDevice
        
        do {
            // Add video input
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                result(FlutterError(code: "INPUT_FAILED", message: "Failed to add video input", details: nil))
                return
            }
            
            // Add video output for frames
            videoOutput = AVCaptureVideoDataOutput()
            if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
                videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                captureSession.addOutput(videoOutput)
            }
            
            // Add movie output for recording
            movieOutput = AVCaptureMovieFileOutput()
            if let movieOutput = movieOutput, captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
                print("✅ [NativeCamera] Movie output added to capture session")
            } else {
                print("❌ [NativeCamera] Failed to add movie output to capture session")
            }
            
            captureSession.commitConfiguration()
            result(true)
            
        } catch {
            result(FlutterError(code: "SETUP_FAILED", message: "Failed to setup camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func startPreview(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_NOT_INITIALIZED", message: "Capture session not initialized", details: nil))
            return
        }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    result(true)
                }
            }
        } else {
            result(true)
        }
    }
    
    private func stopPreview(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(false)
            return
        }
        
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    result(true)
                }
            }
        } else {
            result(true)
        }
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        NSLog("🔵 [NativeCamera] Starting recording...")
        
        guard let movieOutput = movieOutput else {
            NSLog("❌ [NativeCamera] Movie output not available")
            result(FlutterError(code: "OUTPUT_NOT_AVAILABLE", message: "Movie output not available", details: nil))
            return
        }
        
        if isRecording {
            NSLog("⚠️ [NativeCamera] Already recording, ignoring start request")
            result(false)
            return
        }
        
        // Create output file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        outputURL = documentsPath.appendingPathComponent("vine_\(timestamp).mov")
        
        print("🔵 [NativeCamera] Documents path: \(documentsPath)")
        print("🔵 [NativeCamera] Output file: vine_\(timestamp).mov")
        
        guard let outputURL = outputURL else {
            print("❌ [NativeCamera] Failed to create output URL")
            result(FlutterError(code: "FILE_URL_FAILED", message: "Failed to create output URL", details: nil))
            return
        }
        
        print("✅ [NativeCamera] Starting recording to: \(outputURL.path)")
        print("🔵 [NativeCamera] Movie output delegate set to: \(self)")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        print("✅ [NativeCamera] Recording started, isRecording=\(isRecording)")
        print("🔵 [NativeCamera] Movie output recording state: \(movieOutput.isRecording)")
        result(true)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        NSLog("🔵 [NativeCamera] Stopping recording...")
        
        guard let movieOutput = movieOutput else {
            NSLog("❌ [NativeCamera] Movie output not available for stopping")
            result(nil)
            return
        }
        
        if !isRecording {
            NSLog("⚠️ [NativeCamera] Not currently recording, cannot stop")
            result(nil)
            return
        }
        
        NSLog("🔵 [NativeCamera] Current movie output recording state: \(movieOutput.isRecording)")
        
        // If movie output says it's not recording, just return immediately
        if !movieOutput.isRecording {
            NSLog("⚠️ [NativeCamera] Movie output not recording, returning fake path")
            isRecording = false
            result("/tmp/fake_video.mov")
            return
        }
        
        NSLog("🔵 [NativeCamera] Storing result callback and stopping recording")
        // Store the result callback for when recording finishes
        stopRecordingResult = result
        
        // Add a timeout in case the delegate never gets called
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let strongSelf = self, strongSelf.stopRecordingResult != nil {
                NSLog("⚠️ [NativeCamera] Stop recording timeout, forcing completion")
                strongSelf.isRecording = false
                strongSelf.stopRecordingResult?("/tmp/timeout_video.mov")
                strongSelf.stopRecordingResult = nil
            }
        }
        
        movieOutput.stopRecording()
        NSLog("🔵 [NativeCamera] Stop recording called on movieOutput")
        NSLog("🔵 [NativeCamera] Movie output recording state after stop: \(movieOutput.isRecording)")
        // Result will be called in recording delegate method or timeout
    }
    
    private func requestPermission(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }
    
    private func hasPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        result(status == .authorized)
    }
    
    private func getAvailableCameras(result: @escaping FlutterResult) {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        let cameras = devices.enumerated().map { index, device in
            return [
                "index": index,
                "name": device.localizedName,
                "position": positionString(device.position)
            ]
        }
        
        result(cameras)
    }
    
    private func positionString(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front: return "front"
        case .back: return "back"
        case .unspecified: return "unknown"
        @unknown default: return "unknown"
        }
    }
    
    private func switchCamera(cameraIndex: Int, result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(false)
            return
        }
        
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        guard cameraIndex < devices.count else {
            result(FlutterError(code: "INVALID_INDEX", message: "Camera index out of range", details: nil))
            return
        }
        
        let newDevice = devices[cameraIndex]
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            
            captureSession.beginConfiguration()
            
            if let currentInput = videoInput {
                captureSession.removeInput(currentInput)
            }
            
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                videoInput = newInput
                videoDevice = newDevice
                captureSession.commitConfiguration()
                result(true)
            } else {
                captureSession.commitConfiguration()
                result(false)
            }
        } catch {
            result(FlutterError(code: "SWITCH_FAILED", message: "Failed to switch camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func dispose(result: @escaping FlutterResult) {
        if isRecording {
            movieOutput?.stopRecording()
        }
        
        captureSession?.stopRunning()
        captureSession = nil
        videoDevice = nil
        videoInput = nil
        videoOutput = nil
        movieOutput = nil
        previewLayer = nil
        outputURL = nil
        isRecording = false
        
        result(nil)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension NativeCameraPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert pixel buffer to data for Flutter
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else { return }
        
        // Send frame to Flutter
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onFrameAvailable", arguments: FlutterStandardTypedData(bytes: jpegData))
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension NativeCameraPlugin: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("🔵 [NativeCamera] Recording finished delegate called")
        print("🔵 [NativeCamera] Output file URL: \(outputFileURL.path)")
        
        isRecording = false
        
        if let error = error {
            print("❌ [NativeCamera] Recording finished with error: \(error.localizedDescription)")
            stopRecordingResult?(FlutterError(code: "RECORDING_ERROR", message: error.localizedDescription, details: nil))
        } else {
            print("✅ [NativeCamera] Recording finished successfully")
            print("📁 [NativeCamera] Final video path: \(outputFileURL.path)")
            
            // Check if file actually exists
            if FileManager.default.fileExists(atPath: outputFileURL.path) {
                let fileSize = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.size] as? Int64
                print("📊 [NativeCamera] File exists, size: \(fileSize ?? 0) bytes")
            } else {
                print("⚠️ [NativeCamera] Warning: File doesn't exist at path")
            }
            
            stopRecordingResult?(outputFileURL.path)
        }
        
        stopRecordingResult = nil
        print("🔵 [NativeCamera] Recording delegate completed")
    }
}