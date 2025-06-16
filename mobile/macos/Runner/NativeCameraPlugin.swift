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
        switch call.method {
        case "initialize":
            initializeCamera(result: result)
        case "startPreview":
            startPreview(result: result)
        case "stopPreview":
            stopPreview(result: result)
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
        case "requestPermission":
            requestPermission(result: result)
        case "hasPermission":
            hasPermission(result: result)
        case "getAvailableCameras":
            getAvailableCameras(result: result)
        case "switchCamera":
            if let args = call.arguments as? [String: Any],
               let cameraIndex = args["cameraIndex"] as? Int {
                switchCamera(cameraIndex: cameraIndex, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid camera index", details: nil))
            }
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeCamera(result: @escaping FlutterResult) {
        // Check camera permission first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession(result: result)
        case .notDetermined:
            requestPermission { [weak self] granted in
                if granted {
                    self?.setupCaptureSession(result: result)
                } else {
                    result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
                }
            }
        case .denied, .restricted:
            result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
        @unknown default:
            result(FlutterError(code: "PERMISSION_UNKNOWN", message: "Unknown permission status", details: nil))
        }
    }
    
    private func setupCaptureSession(result: @escaping FlutterResult) {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_FAILED", message: "Failed to create capture session", details: nil))
            return
        }
        
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
        guard let movieOutput = movieOutput else {
            result(FlutterError(code: "OUTPUT_NOT_AVAILABLE", message: "Movie output not available", details: nil))
            return
        }
        
        if isRecording {
            result(false)
            return
        }
        
        // Create output file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        outputURL = documentsPath.appendingPathComponent("vine_\(timestamp).mov")
        
        guard let outputURL = outputURL else {
            result(FlutterError(code: "FILE_URL_FAILED", message: "Failed to create output URL", details: nil))
            return
        }
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        result(true)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        guard let movieOutput = movieOutput else {
            result(nil)
            return
        }
        
        if !isRecording {
            result(nil)
            return
        }
        
        movieOutput.stopRecording()
        // Result will be called in recording delegate method
    }
    
    private func requestPermission(result: @escaping FlutterResult) {
        requestPermission { granted in
            result(granted)
        }
    }
    
    private func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
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
        isRecording = false
        
        if let error = error {
            methodChannel?.invokeMethod("onRecordingError", arguments: error.localizedDescription)
        } else {
            methodChannel?.invokeMethod("onRecordingFinished", arguments: outputFileURL.path)
        }
    }
}