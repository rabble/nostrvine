// ABOUTME: Fallback camera provider for unsupported platforms
// ABOUTME: Provides graceful degradation instead of crashes

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'camera_provider.dart';

/// Camera provider for unsupported platforms
/// 
/// This provider ensures the app doesn't crash on platforms where
/// camera functionality isn't available, providing graceful degradation.
class UnsupportedCameraProvider implements CameraProvider {
  @override
  bool get isInitialized => false;
  
  @override
  Future<void> initialize() async {
    throw CameraProviderException('Camera functionality is not supported on this platform');
  }
  
  @override
  Widget buildPreview() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'Camera Not Supported',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This platform doesn\'t support camera functionality',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Future<void> startRecording({Function(Uint8List)? onFrame}) async {
    throw CameraProviderException('Recording is not supported on this platform');
  }
  
  @override
  Future<CameraRecordingResult> stopRecording() async {
    throw CameraProviderException('Recording is not supported on this platform');
  }
  
  @override
  Future<void> switchCamera() async {
    throw CameraProviderException('Camera switching is not supported on this platform');
  }
  
  @override
  Size? getCurrentResolution() {
    return null; // No camera, no resolution
  }
  
  @override
  String getResolutionString() {
    return 'Not Available';
  }
  
  @override
  Future<void> dispose() async {
    // Nothing to dispose
  }
}