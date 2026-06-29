// ABOUTME: Pre-navigation camera permission check for camera routes
// ABOUTME: Routes requestable permissions to VideoRecorderScreen's gate

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Extension for camera navigation with pre-flight permission check.
extension CameraPermissionNavigation on BuildContext {
  /// Navigates to [VideoRecorderScreen] after the permission status has
  /// settled.
  ///
  /// Permission prompts are owned by [VideoRecorderScreen]'s
  /// `CameraPermissionGate`, so the native media permission request happens
  /// from the recorder's explicit Continue action rather than from a
  /// pre-navigation bottom sheet. This method only waits for the bloc to
  /// resolve out of its initial state so the gate renders the correct screen
  /// immediately on arrival.
  ///
  /// Returns `true` if navigation occurred.
  Future<bool> pushToCameraWithPermission() async {
    final bloc = read<CameraPermissionBloc>();

    if (kIsWeb) {
      await pushWithVideoPause(VideoRecorderScreen.path);
      return true;
    }

    await _awaitPermissionResolved(bloc);
    if (!mounted) return false;

    // Navigate for every resolved status. The route gate renders the
    // authorized camera, the canRequest prompt, the requiresSettings prompt,
    // or the loading/error UI, and owns the native permission request.
    await pushWithVideoPause(VideoRecorderScreen.path);
    return true;
  }
}

/// Waits until the permission bloc has settled out of its initial/loading
/// state so the recorder gate renders the correct screen on arrival.
///
/// Triggers a refresh first when no check has run yet, and falls back after a
/// timeout so navigation is never blocked on a stream that never emits.
Future<void> _awaitPermissionResolved(CameraPermissionBloc bloc) async {
  final current = bloc.state;
  if (current is CameraPermissionLoaded || current is CameraPermissionError) {
    return;
  }

  // Not yet loaded — trigger refresh and wait for the result.
  if (current is CameraPermissionInitial) {
    bloc.add(const CameraPermissionRefresh());
  }

  await bloc.stream
      .firstWhere(
        (s) => s is CameraPermissionLoaded || s is CameraPermissionError,
      )
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => const CameraPermissionError(),
      );
}
