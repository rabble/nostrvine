// ABOUTME: Native macOS camera interface using platform channels
// ABOUTME: Communicates with Swift AVFoundation implementation for real camera access

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native macOS camera interface using platform channels
class NativeMacOSCamera {
  static const MethodChannel _channel = MethodChannel('nostrvine/native_camera');
  
  static StreamController<Uint8List>? _frameStreamController;
  static Stream<Uint8List>? _frameStream;
  
  /// Initialize the native camera
  static Future<bool> initialize() async {
    try {
      debugPrint('🔵 [NativeMacOSCamera] Calling native initialize method');
      final result = await _channel.invokeMethod<bool>('initialize');
      debugPrint('🔵 [NativeMacOSCamera] Initialize result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ [NativeMacOSCamera] Failed to initialize native camera: $e');
      return false;
    }
  }
  
  /// Start camera preview
  static Future<bool> startPreview() async {
    try {
      debugPrint('🔵 [NativeMacOSCamera] Calling startPreview method');
      final result = await _channel.invokeMethod<bool>('startPreview');
      debugPrint('🔵 [NativeMacOSCamera] StartPreview result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ [NativeMacOSCamera] Failed to start native camera preview: $e');
      return false;
    }
  }
  
  /// Stop camera preview
  static Future<bool> stopPreview() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopPreview');
      debugPrint('📸 Native macOS camera preview stopped: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to stop native camera preview: $e');
      return false;
    }
  }
  
  /// Start video recording
  static Future<bool> startRecording() async {
    try {
      debugPrint('🔵 [NativeMacOSCamera] Calling startRecording method');
      final result = await _channel.invokeMethod<bool>('startRecording');
      debugPrint('🔵 [NativeMacOSCamera] StartRecording result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ [NativeMacOSCamera] Failed to start native camera recording: $e');
      return false;
    }
  }
  
  /// Stop video recording and return file path
  static Future<String?> stopRecording() async {
    try {
      debugPrint('🔵 [NativeMacOSCamera] Calling stopRecording method with timeout');
      
      // Add timeout to prevent hanging forever
      final result = await _channel.invokeMethod<String>('stopRecording').timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏰ [NativeMacOSCamera] stopRecording timed out after 3 seconds');
          return null;
        },
      );
      
      debugPrint('🔵 [NativeMacOSCamera] StopRecording result: $result');
      if (result != null) {
        debugPrint('📁 [NativeMacOSCamera] Video saved to: $result');
      } else {
        debugPrint('⚠️ [NativeMacOSCamera] No video path returned');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [NativeMacOSCamera] Failed to stop native camera recording: $e');
      return null;
    }
  }
  
  /// Get frame stream for real-time capture
  static Stream<Uint8List> get frameStream {
    if (_frameStream == null) {
      _frameStreamController = StreamController<Uint8List>.broadcast();
      _frameStream = _frameStreamController!.stream;
      
      // Set up method call handler for frames
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onFrameAvailable') {
          final frameData = call.arguments as Uint8List;
          // Uncomment for very verbose frame logging (will spam logs)
          // debugPrint('🖼️ [NativeMacOSCamera] Frame received: ${frameData.length} bytes');
          _frameStreamController?.add(frameData);
        }
      });
    }
    return _frameStream!;
  }
  
  /// Request permission to access camera
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      debugPrint('🔐 Camera permission result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to request camera permission: $e');
      return false;
    }
  }
  
  /// Check if camera permission is granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to check camera permission: $e');
      return false;
    }
  }
  
  /// Get available cameras
  static Future<List<Map<String, dynamic>>> getAvailableCameras() async {
    try {
      final result = await _channel.invokeMethod<List>('getAvailableCameras');
      return result?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('❌ Failed to get available cameras: $e');
      return [];
    }
  }
  
  /// Switch to camera by index
  static Future<bool> switchCamera(int cameraIndex) async {
    try {
      final result = await _channel.invokeMethod<bool>('switchCamera', {
        'cameraIndex': cameraIndex,
      });
      debugPrint('🔄 Switched to camera $cameraIndex: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
      return false;
    }
  }
  
  /// Dispose native camera resources
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _frameStreamController?.close();
      _frameStreamController = null;
      _frameStream = null;
      debugPrint('🧹 Native macOS camera disposed');
    } catch (e) {
      debugPrint('❌ Error disposing native camera: $e');
    }
  }
}