// ABOUTME: Mock implementation of CameraService for testing
// ABOUTME: Provides a fake camera service that doesn't require actual hardware

import 'package:divine_camera/divine_camera.dart'
    show DivineCameraLens, DivineVideoQuality;
import 'package:flutter/material.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Mock camera service for testing without requiring actual camera hardware
class MockCameraService extends CameraService {
  bool _isInitialized = false;
  bool _isRecording = false;
  double zoomLevel = 1.0;
  DivineFlashMode flashMode = DivineFlashMode.auto;
  Offset focusPoint = Offset.zero;
  DivineCameraLens _currentLens = DivineCameraLens.back;

  MockCameraService.create({
    required super.onUpdateState,
    required super.onAutoStopped,
  });

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
  }) async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async {
    flashMode = mode;
    return true;
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    focusPoint = offset;
    return true;
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    return true;
  }

  @override
  Future<bool> setZoomLevel(double value) async {
    zoomLevel = value;
    return true;
  }

  @override
  Future<bool> switchCamera() async {
    _currentLens = _currentLens.opposite;
    return true;
  }

  @override
  Future<bool> setLens(DivineCameraLens lens) async {
    _currentLens = lens;
    return true;
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    _isRecording = true;
    return true;
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    _isRecording = false;
    return null; // Return null in mock
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    // Mock implementation - do nothing, just return successfully
    return;
  }

  @override
  double get cameraAspectRatio => 16 / 9;

  @override
  double get minZoomLevel => 1.0;

  @override
  double get maxZoomLevel => 8.0;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFocusPointSupported => true;

  @override
  bool get canRecord => _isInitialized && !_isRecording;

  @override
  bool get canSwitchCamera => true;

  @override
  bool get hasFlash => true;

  @override
  DivineCameraLens get currentLens => _currentLens;

  @override
  List<DivineCameraLens> get availableLenses => [
    DivineCameraLens.front,
    DivineCameraLens.back,
    DivineCameraLens.ultraWide,
  ];

  @override
  String? get initializationError => null;
}
