// ABOUTME: Native macOS camera permission handling using AVFoundation
// ABOUTME: Provides camera permission checks and system settings navigation

import FlutterMacOS
import AVFoundation
import Foundation

public class NativeCameraPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "openvine/native_camera",
            binaryMessenger: registrar.messenger
        )
        let instance = NativeCameraPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Method called: \(call.method)")
        print("🔵 [NativeCamera] Current thread: \(Thread.current)")
        print("🔵 [NativeCamera] Is main thread: \(Thread.isMainThread)")
        
        switch call.method {
        case "requestPermission":
            print("🔵 [NativeCamera] Handling requestPermission request")
            requestPermission(result: result)
        case "hasPermission":
            print("🔵 [NativeCamera] Handling hasPermission request")
            hasPermission(result: result)
        case "openSystemSettings":
            print("🔵 [NativeCamera] Handling openSystemSettings request")
            openSystemSettings(result: result)
        default:
            print("❌ [NativeCamera] Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func requestPermission(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Requesting camera permission explicitly")
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔵 [NativeCamera] Current status before request: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            print("✅ [NativeCamera] Permission already granted")
            DispatchQueue.main.async {
                result(true)
            }
            
        case .denied, .restricted:
            print("❌ [NativeCamera] Permission previously denied or restricted")
            print("💡 [NativeCamera] User must enable camera in System Settings")
            
            // Return error with instruction to open settings
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "PERMISSION_DENIED",
                    message: "Camera permission denied. Please enable camera access in System Settings > Privacy & Security > Camera",
                    details: ["openSettings": true, "status": currentStatus.rawValue]
                ))
            }
            
        case .notDetermined:
            print("🔵 [NativeCamera] Permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("🔵 [NativeCamera] Permission request completed with result: \(granted)")
                let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
                print("🔵 [NativeCamera] New status after request: \(newStatus.rawValue)")
                
                DispatchQueue.main.async {
                    result(granted)
                }
            }
            
        @unknown default:
            print("⚠️ [NativeCamera] Unknown permission status")
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "PERMISSION_UNKNOWN",
                    message: "Unknown camera permission status",
                    details: nil
                ))
            }
        }
    }
    
    private func hasPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔵 [NativeCamera] Checking permission status: \(status.rawValue)")
        print("🔵 [NativeCamera] Status meanings: 0=notDetermined, 1=restricted, 2=denied, 3=authorized")
        result(status == .authorized)
    }
    
    private func openSystemSettings(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Opening System Settings for camera privacy")
        
        // On macOS 13+ (Ventura), we need to use a different approach
        // The app only appears in Settings after it has requested camera access at least once
        
        // Try modern approach first (macOS 13+)
        if #available(macOS 13.0, *) {
            // Modern URL scheme for System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
                print("✅ [NativeCamera] System Settings opened (macOS 13+)")
                result(true)
                return
            }
        }
        
        // Fallback to older approach (macOS 12 and below)
        // Note: This opens System Preferences, not System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
            print("✅ [NativeCamera] System Preferences opened (macOS 12-)") 
            result(true)
        } else {
            print("❌ [NativeCamera] Failed to create settings URL")
            
            // Last resort: Just open the Privacy & Security pane
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = ["-b", "com.apple.systempreferences", "/System/Library/PreferencePanes/Security.prefPane"]
            
            do {
                try task.run()
                print("✅ [NativeCamera] Opened Security pane via command line")
                result(true)
            } catch {
                print("❌ [NativeCamera] Failed to open settings: \(error)")
                result(false)
            }
        }
    }
}