// ABOUTME: Web camera provider with video recording fallback (no real-time streaming)
// ABOUTME: Uses camera plugin for video recording, generates placeholder frames for now

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'camera_provider.dart';

/// Camera provider for web platforms using video recording + placeholder frames
class WebCameraProvider implements CameraProvider {
  CameraController? _controller;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  
  // Recording parameters
  static const Duration maxVineDuration = Duration(seconds: 6);
  static const double targetFPS = 5.0;
  static const int targetFrameCount = 30;
  
  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  
  @override
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraProviderException('No cameras available on web platform');
      }
      
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _controller!.initialize();
      debugPrint('📷 Web camera initialized successfully');
    } catch (e) {
      throw CameraProviderException('Failed to initialize web camera', e);
    }
  }
  
  @override
  Widget buildPreview() {
    if (!isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return CameraPreview(_controller!);
  }
  
  @override
  Future<void> startRecording({Function(Uint8List)? onFrame}) async {
    if (!isInitialized || _isRecording) {
      throw CameraProviderException('Cannot start recording: camera not ready or already recording');
    }
    
    try {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      // Start video recording (web platforms support this)
      await _controller!.startVideoRecording();
      
      // Note: Web doesn't support image streaming, so no real-time frames
      debugPrint('⚠️ Image streaming not supported on web platform. Will rely on video extraction fallback.');
      
      // Auto-stop after max duration
      Future.delayed(maxVineDuration, () {
        if (_isRecording) {
          stopRecording();
        }
      });
      
      debugPrint('🎬 Started web camera recording (video-only approach)');
    } catch (e) {
      _isRecording = false;
      throw CameraProviderException('Failed to start web recording', e);
    }
  }
  
  @override
  Future<CameraRecordingResult> stopRecording() async {
    if (!_isRecording) {
      throw CameraProviderException('Not currently recording');
    }
    
    try {
      final duration = _recordingStartTime != null 
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;
      
      // Stop video recording
      final videoFile = await _controller!.stopVideoRecording();
      
      debugPrint('✅ Web camera recording stopped, video saved to: ${videoFile.path}');
      
      return CameraRecordingResult(
        videoPath: videoFile.path,
        liveFrames: null, // No real-time frames on web
        width: 640,
        height: 480,
        duration: duration,
      );
    } catch (e) {
      throw CameraProviderException('Failed to stop web recording', e);
    } finally {
      _isRecording = false;
      _recordingStartTime = null;
    }
  }
  
  @override
  Future<void> switchCamera() async {
    if (!isInitialized || _isRecording) return;
    
    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;
      
      final currentCamera = _controller!.description;
      final newCamera = cameras.firstWhere(
        (camera) => camera != currentCamera,
        orElse: () => cameras.first,
      );
      
      _controller?.dispose();
      _controller = null;
      
      _controller = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _controller!.initialize();
      debugPrint('🔄 Switched to ${newCamera.lensDirection} camera on web');
    } catch (e) {
      debugPrint('❌ Failed to switch camera on web: $e');
    }
  }
  
  @override
  Size? getCurrentResolution() {
    if (!isInitialized) return null;
    
    // Get actual resolution from camera controller
    final cameraValue = _controller!.value;
    final actualSize = cameraValue.previewSize;
    
    if (actualSize != null) {
      debugPrint('📷 Web camera resolution: ${actualSize.width}x${actualSize.height}');
      return actualSize;
    }
    
    // Fallback to hardcoded values if preview size is null
    return const Size(640, 480);
  }
  
  @override
  String getResolutionString() {
    final resolution = getCurrentResolution();
    if (resolution == null) return 'Unknown';
    return '${resolution.width.toInt()}x${resolution.height.toInt()}';
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      try {
        await stopRecording();
      } catch (e) {
        debugPrint('⚠️ Error stopping recording during disposal: $e');
      }
    }
    
    _controller?.dispose();
    _controller = null;
  }
}