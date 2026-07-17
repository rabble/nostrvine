import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/native_camera_permission_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'camera_permission_event.dart';
part 'camera_permission_state.dart';

/// BLoC for managing camera and microphone permissions.
///
/// A [CameraPermissionRequest] fires the native OS permission dialog directly —
/// dispatched by `pushToCameraWithPermission` on the current page, or by
/// `CameraPermissionGate` on direct navigation to the recorder. There is no
/// in-app priming screen; the dialog always follows the user's camera gesture.
///
/// Handles:
/// - Checking current permission status
/// - Requesting permissions via the OS dialog (from
///   `pushToCameraWithPermission` on the current page, or the gate)
/// - Caching status to avoid repeated OS calls
/// - Refreshing status when app resumes from background
///
/// [CameraPermissionRefresh] uses `droppable()` so overlapping refreshes are
/// ignored. [CameraPermissionRequest] uses `restartable()`: a new request
/// supersedes an in-flight one. This matters because `permission_handler`'s
/// native `request()` can hang and never complete when the Android permission
/// dialog is dismissed with the back button — `droppable()` would then block
/// every later request forever. `restartable()` lets the next camera tap
/// abandon the stuck request and fire a fresh native dialog.
///
/// Accepted tradeoff of `restartable()`: on a fast double-tap, the second
/// request supersedes the first while its dialog is still live, so a grant on
/// that first dialog is dropped and that one tap resolves to nothing. It
/// self-heals on the next tap (a refresh sees the OS grant and navigates), so
/// the visible cost is a single dead tap on an uncommon race — preferred over
/// permanently stranding the recorder on the back-dismiss hang.
class CameraPermissionBloc
    extends Bloc<CameraPermissionEvent, CameraPermissionState> {
  CameraPermissionBloc({
    required PermissionsService permissionsService,
    NativeCameraPermissionService? nativeCameraPermissionService,
    @visibleForTesting bool? skipLinuxBypass,
    @visibleForTesting bool? skipMacOSBypass,
  }) : _permissionsService = permissionsService,
       _skipLinuxBypass = skipLinuxBypass ?? false,
       _nativeCameraPermissionService =
           nativeCameraPermissionService ??
           const MethodChannelNativeCameraPermissionService(),
       _skipMacOSBypass = skipMacOSBypass ?? false,
       super(const CameraPermissionInitial()) {
    on<CameraPermissionRequest>(_onRequest, transformer: restartable());
    on<CameraPermissionRefresh>(_onRefresh, transformer: droppable());
    on<CameraPermissionOpenSettings>(_onOpenSettings);
  }

  final PermissionsService _permissionsService;
  final bool _skipLinuxBypass;
  final NativeCameraPermissionService _nativeCameraPermissionService;
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

    // Emit a distinct loading state so a denial that leaves the permission
    // still requestable (canRequest -> canRequest) is observable as a real
    // transition. Without it, the equal Loaded(canRequest) emit is suppressed
    // by Equatable and the caller can't tell the request finished.
    emit(const CameraPermissionLoading());

    try {
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.macOS &&
          !_skipMacOSBypass) {
        final cameraResult = await _nativeCameraPermissionService
            .requestPermission();
        final cameraState = _mapNativeRequestResult(cameraResult);
        if (cameraState != null) {
          emit(cameraState);
          return;
        }

        final microphoneResult = await _nativeCameraPermissionService
            .requestMicrophonePermission();
        final microphoneState = _mapNativeRequestResult(microphoneResult);
        if (microphoneState != null) {
          emit(microphoneState);
          return;
        }

        await _permissionsService.requestGalleryPermission();
        emit(const CameraPermissionLoaded(CameraPermissionStatus.authorized));
        return;
      }

      final cameraStatus = await _permissionsService.requestCameraPermission();

      if (cameraStatus != PermissionStatus.granted) {
        // Surface the resolved status so the caller can re-prompt (canRequest)
        // or send the user to Settings (requiresSettings) instead of silently
        // bouncing back to the feed.
        emit(CameraPermissionLoaded(_cameraStatusFromPermission(cameraStatus)));
        return;
      }

      final microphoneStatus = await _permissionsService
          .requestMicrophonePermission();

      if (microphoneStatus != PermissionStatus.granted) {
        emit(
          CameraPermissionLoaded(_cameraStatusFromPermission(microphoneStatus)),
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

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS &&
        !_skipMacOSBypass) {
      try {
        final status = await _checkMacOSPermissions();
        Log.info(
          '🔐 Native macOS permission check result: $status',
          name: 'CameraPermissionBloc',
          category: LogCategory.video,
        );
        emit(CameraPermissionLoaded(status));
      } catch (e) {
        Log.error(
          '🔐 Native macOS permission check failed: $e',
          name: 'CameraPermissionBloc',
          category: LogCategory.video,
        );
        emit(const CameraPermissionError());
      }
      return;
    }

    // Linux has no camera support yet, so permissions are irrelevant.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.linux &&
        !_skipLinuxBypass) {
      Log.info(
        '🔐 Linux detected - bypassing permission checks',
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
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS &&
        !_skipMacOSBypass) {
      return _checkMacOSPermissions();
    }

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

  Future<CameraPermissionStatus> _checkMacOSPermissions() async {
    final cameraStatus = await _nativeCameraPermissionService
        .authorizationStatus();
    final microphoneStatus = await _nativeCameraPermissionService
        .microphoneAuthorizationStatus();

    if (cameraStatus == NativeCameraAuthorizationStatus.authorized &&
        microphoneStatus == NativeCameraAuthorizationStatus.authorized) {
      return CameraPermissionStatus.authorized;
    }

    if (cameraStatus == NativeCameraAuthorizationStatus.denied ||
        cameraStatus == NativeCameraAuthorizationStatus.restricted ||
        microphoneStatus == NativeCameraAuthorizationStatus.denied ||
        microphoneStatus == NativeCameraAuthorizationStatus.restricted) {
      return CameraPermissionStatus.requiresSettings;
    }

    return CameraPermissionStatus.canRequest;
  }

  CameraPermissionState? _mapNativeRequestResult(
    NativeCameraPermissionStatus status,
  ) {
    return switch (status) {
      NativeCameraPermissionStatus.granted => null,
      NativeCameraPermissionStatus.denied ||
      NativeCameraPermissionStatus.requiresSettings =>
        const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
      NativeCameraPermissionStatus.promptBlocked =>
        const CameraPermissionLoaded(CameraPermissionStatus.launchBlocked),
      NativeCameraPermissionStatus.unavailable => const CameraPermissionError(),
    };
  }
}
