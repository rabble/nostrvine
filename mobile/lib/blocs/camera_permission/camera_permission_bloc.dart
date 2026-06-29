import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'camera_permission_event.dart';
part 'camera_permission_state.dart';

/// BLoC for managing camera and microphone permissions.
///
/// Permission prompting is owned by the recorder gate
/// (`CameraPermissionGate`): a [CameraPermissionRequest] is only dispatched
/// from the gate's explicit "Continue" action, so the native media permission
/// dialog always happens in response to a user gesture on the recorder
/// screen. Callers that navigate to the recorder no longer prompt themselves.
///
/// Handles:
/// - Checking current permission status
/// - Requesting permissions via OS dialog (from the gate)
/// - Caching status to avoid repeated OS calls
/// - Refreshing status when app resumes from background
///
/// Both [CameraPermissionRequest] and [CameraPermissionRefresh] use the
/// `droppable()` transformer so duplicate requests/refreshes dispatched while
/// one is already in flight are ignored. This replaces the previous in-flight
/// boolean/future fields with the idiomatic bloc concurrency primitive and
/// keeps all coordination out of mutable instance state.
class CameraPermissionBloc
    extends Bloc<CameraPermissionEvent, CameraPermissionState> {
  CameraPermissionBloc({
    required PermissionsService permissionsService,
    @visibleForTesting bool? skipMacOSBypass,
  }) : _permissionsService = permissionsService,
       _skipMacOSBypass = skipMacOSBypass ?? false,
       super(const CameraPermissionInitial()) {
    on<CameraPermissionRequest>(_onRequest, transformer: droppable());
    on<CameraPermissionRefresh>(_onRefresh, transformer: droppable());
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
        // Stay on the recorder gate with the resolved status so the gate can
        // re-prompt (canRequest) or send the user to Settings
        // (requiresSettings) instead of silently bouncing back to the feed.
        emit(CameraPermissionLoaded(_cameraStatusFromPermission(cameraStatus)));
        return;
      }

      final microphoneStatus = await _permissionsService
          .requestMicrophonePermission();

      if (microphoneStatus != PermissionStatus.granted) {
        emit(
          CameraPermissionLoaded(
            _cameraStatusFromPermission(microphoneStatus),
          ),
        );
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

    // Linux has no camera support yet, so permissions are irrelevant and we
    // assume authorized. macOS permission behavior is tracked separately in
    // #4112; this refactor intentionally leaves the desktop bypass untouched.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux) &&
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

  /// Maps a raw [PermissionStatus] from a request to the gate-facing
  /// [CameraPermissionStatus] so a denied/blocked request keeps the user on
  /// the recorder gate with the correct prompt.
  CameraPermissionStatus _cameraStatusFromPermission(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted => CameraPermissionStatus.authorized,
        PermissionStatus.requiresSettings =>
          CameraPermissionStatus.requiresSettings,
        PermissionStatus.canRequest => CameraPermissionStatus.canRequest,
      };

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
