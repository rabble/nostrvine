import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:permissions_service/permissions_service.dart';

part 'camera_permission_event.dart';
part 'camera_permission_state.dart';

/// BLoC for managing camera and microphone permissions.
///
/// Handles:
/// - Checking current permission status
/// - Requesting permissions via OS dialog
/// - Caching status to avoid repeated OS calls
/// - Refreshing status when app resumes from background
class CameraPermissionBloc
    extends Bloc<CameraPermissionEvent, CameraPermissionState> {
  CameraPermissionBloc({
    required PermissionsService permissionsService,
    @visibleForTesting bool? skipMacOSBypass,
  }) : _permissionsService = permissionsService,
       _skipMacOSBypass = skipMacOSBypass ?? false,
       super(const CameraPermissionInitial()) {
    on<CameraPermissionRequest>(_onRequest);
    on<CameraPermissionRefresh>(_onRefresh);
    on<CameraPermissionOpenSettings>(_onOpenSettings);
  }

  final PermissionsService _permissionsService;
  final bool _skipMacOSBypass;

  Future<void> _onRequest(
    CameraPermissionRequest event,
    Emitter<CameraPermissionState> emit,
  ) async {
    final currentState = state;

    if (currentState is! CameraPermissionLoaded) {
      return;
    }

    if (currentState.status != CameraPermissionStatus.canRequest) {
      return;
    }

    try {
      final cameraStatus = await _permissionsService.requestCameraPermission();

      if (cameraStatus != PermissionStatus.granted) {
        emit(const CameraPermissionDenied());
        return;
      }

      final microphoneStatus = await _permissionsService
          .requestMicrophonePermission();

      if (microphoneStatus != PermissionStatus.granted) {
        emit(const CameraPermissionDenied());
        return;
      }

      // Note: Gallery permission is optional. We don't block recording if
      // gallery access is denied - the video will still upload, just won't
      // be saved locally.
      await _permissionsService.requestGalleryPermission();

      emit(const CameraPermissionLoaded(CameraPermissionStatus.authorized));
    } catch (e) {
      emit(const CameraPermissionError());
    }
  }

  Future<void> _onRefresh(
    CameraPermissionRefresh event,
    Emitter<CameraPermissionState> emit,
  ) async {
    Log.info(
      '🔐 Refreshing camera permissions',
      name: 'CameraPermissionBloc',
      category: LogCategory.video,
    );

    // On desktop, permission_handler doesn't work reliably.
    // macOS handles camera permissions at the system level when the app
    // actually tries to access the camera, showing its own permission dialog.
    // Linux has no camera support yet, so permissions are irrelevant.
    // So we bypass the permission check and assume authorized.
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isLinux) &&
        !_skipMacOSBypass) {
      Log.info(
        '🔐 Desktop detected - bypassing permission_handler, '
        'assuming authorized',
        name: 'CameraPermissionBloc',
        category: LogCategory.video,
      );
      emit(const CameraPermissionLoaded(CameraPermissionStatus.authorized));
      return;
    }

    try {
      final status = await checkPermissions();
      Log.info(
        '🔐 Permission check result: $status',
        name: 'CameraPermissionBloc',
        category: LogCategory.video,
      );
      emit(CameraPermissionLoaded(status));
    } catch (e) {
      Log.error(
        '🔐 Permission check failed: $e',
        name: 'CameraPermissionBloc',
        category: LogCategory.video,
      );
      emit(const CameraPermissionError());
    }
  }

  Future<void> _onOpenSettings(
    CameraPermissionOpenSettings event,
    Emitter<CameraPermissionState> emit,
  ) async {
    await _permissionsService.openAppSettings();
  }

  /// Check the status of camera, microphone, and gallery permissions.
  Future<CameraPermissionStatus> checkPermissions() async {
    final (cameraStatus, micStatus) = await (
      _permissionsService.checkCameraStatus(),
      _permissionsService.checkMicrophoneStatus(),
    ).wait;

    if (cameraStatus == PermissionStatus.granted &&
        micStatus == PermissionStatus.granted) {
      return CameraPermissionStatus.authorized;
    }

    if (cameraStatus == PermissionStatus.requiresSettings ||
        micStatus == PermissionStatus.requiresSettings) {
      return CameraPermissionStatus.requiresSettings;
    }

    return CameraPermissionStatus.canRequest;
  }
}
