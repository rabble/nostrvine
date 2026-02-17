// ABOUTME: Haptic feedback service for the video editor.
// ABOUTME: Provides platform-aware vibration for UI interactions like
// ABOUTME: guideline hits and layer transformations.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:vibration/vibration.dart';

/// Service for haptic feedback in the video editor.
///
/// Handles platform-specific vibration logic and caches device capabilities
/// to avoid repeated async checks on every haptic trigger.
///
/// Usage:
/// ```dart
/// await VideoEditorHapticService.instance.initialize();
/// VideoEditorHapticService.instance.guidelineHit();
/// ```
class VideoEditorHapticService {
  VideoEditorHapticService._();

  /// Singleton instance.
  static final instance = VideoEditorHapticService._();

  bool _isInitialized = false;
  bool _hasVibrator = false;
  bool _hasCustomVibration = false;

  /// Whether the device supports any form of vibration.
  bool get isSupported => _hasVibrator;

  /// Whether the device supports custom vibration durations.
  bool get supportsCustomDuration => _hasCustomVibration;

  /// Initializes the service by checking device capabilities.
  ///
  /// This should be called once during app startup or when entering
  /// the video editor. Subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Web doesn't support the vibration package
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      _hasVibrator = await Vibration.hasVibrator();

      if (_hasVibrator) {
        _hasCustomVibration = await Vibration.hasCustomVibrationsSupport();
      }
    } catch (e) {
      Log.warning(
        'Failed to check vibration capabilities: $e',
        name: 'VideoEditorHapticService',
        category: LogCategory.video,
      );
      // Disable haptics on failure
      _hasVibrator = false;
      _hasCustomVibration = false;
    }

    _isInitialized = true;

    Log.debug(
      'Haptics initialized - '
      'hasVibrator: $_hasVibrator, '
      'customDuration: $_hasCustomVibration',
      name: 'VideoEditorHapticService',
      category: LogCategory.video,
    );
  }

  /// Triggers a brief haptic feedback when a guideline is hit.
  ///
  /// Uses a 3ms vibration for subtle feedback. On older Android devices
  /// without custom vibration support, it starts and cancels the vibration
  /// to simulate a short pulse.
  Future<void> guidelineHit() async {
    await _vibrate(durationMs: 2);
  }

  /// Triggers haptic feedback when a layer enters the remove area.
  ///
  /// Uses a slightly longer vibration (10ms) to indicate a destructive action.
  Future<void> layerOverRemoveArea() async {
    await _vibrate(durationMs: 10);
  }

  /// Triggers haptic feedback when a clip enters the delete zone.
  ///
  /// Uses the same vibration as [layerOverRemoveArea] for consistency.
  Future<void> clipOverRemoveArea() => layerOverRemoveArea();

  /// Internal helper to trigger vibration with error handling.
  ///
  /// Silently fails on error - haptic feedback is non-critical.
  Future<void> _vibrate({required int durationMs}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_hasVibrator) return;

    try {
      if (_hasCustomVibration) {
        await Vibration.vibrate(duration: durationMs);
      } else if (!kIsWeb && Platform.isAndroid) {
        // On older Android devices without custom vibration support,
        // we start the default vibration and cancel it after the duration.
        // iOS requires CHHapticEngine for custom durations, but devices
        // supporting that will have hasCustomVibrationsSupport = true.
        await Vibration.vibrate();
        await Future<void>.delayed(Duration(milliseconds: durationMs));
        await Vibration.cancel();
      }
    } catch (_) {
      // Silently ignore - haptic feedback is non-critical and should not spam
      // in the logs.
    }
  }
}
