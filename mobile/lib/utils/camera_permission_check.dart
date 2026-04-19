// ABOUTME: Pre-navigation camera permission check with bottom sheet UI
// ABOUTME: Shows permission sheet before navigating to VideoRecorderScreen

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Extension for camera navigation with pre-flight permission check.
extension CameraPermissionNavigation on BuildContext {
  /// Checks camera/microphone permissions and shows a bottom sheet if
  /// not authorized. Navigates to [VideoRecorderScreen] only when
  /// permissions are granted.
  ///
  /// Returns `true` if navigation occurred.
  Future<bool> pushToCameraWithPermission() async {
    final bloc = read<CameraPermissionBloc>();

    if (kIsWeb) {
      await pushWithVideoPause(VideoRecorderScreen.path);
      return true;
    }

    final status = await _resolvePermissionStatus(bloc);
    if (!mounted) return false;

    // Couldn't determine status, already authorized, or requiresSettings
    // → navigate directly (CameraPermissionGate handles the rest)
    if (status == null ||
        status == .authorized ||
        status == .requiresSettings) {
      await pushWithVideoPause(VideoRecorderScreen.path);
      return true;
    }

    // canRequest → show bottom sheet
    var permissionRequested = false;
    await VineBottomSheetPrompt.show<void>(
      context: this,
      sticker: DivineStickerName.skeletonKey,
      title: l10n.cameraPermissionAllowAccessTitle,
      subtitle: l10n.cameraPermissionAllowAccessDescription,
      primaryButtonText: l10n.cameraPermissionContinue,
      onPrimaryPressed: () {
        permissionRequested = true;
        Navigator.of(this).pop();
      },
      secondaryButtonText: l10n.cameraPermissionNotNow,
      onSecondaryPressed: () => Navigator.of(this).pop(),
    );

    if (!permissionRequested || !mounted) return false;

    bloc.add(const CameraPermissionRequest());
    final result = await bloc.stream.firstWhere(
      (s) =>
          s is CameraPermissionLoaded ||
          s is CameraPermissionDenied ||
          s is CameraPermissionError,
    );
    if (!mounted) return false;
    if (result is CameraPermissionLoaded &&
        result.status == CameraPermissionStatus.authorized) {
      await pushWithVideoPause(VideoRecorderScreen.path);
      return true;
    }
    return false;
  }
}

/// Returns the current permission status, or `null` if it couldn't be
/// determined (error / denied / unknown).
Future<CameraPermissionStatus?> _resolvePermissionStatus(
  CameraPermissionBloc bloc,
) async {
  final current = bloc.state;
  if (current is CameraPermissionLoaded) return current.status;

  // Not yet loaded — trigger refresh if idle and wait
  if (current is CameraPermissionInitial) {
    bloc.add(const CameraPermissionRefresh());
  }

  final state = await bloc.stream.firstWhere(
    (s) =>
        s is CameraPermissionLoaded ||
        s is CameraPermissionError ||
        s is CameraPermissionDenied,
  );

  if (state is CameraPermissionLoaded) return state.status;
  return null;
}
