import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  CameraPermissionBloc({required PermissionsService permissionsService})
    : _permissionsService = permissionsService,
      super(const CameraPermissionInitial()) {
    on<CameraPermissionRequest>(_onRequest);
    on<CameraPermissionRefresh>(_onRefresh);
    on<CameraPermissionOpenSettings>(_onOpenSettings);
  }

  final PermissionsService _permissionsService;

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

      emit(const CameraPermissionLoaded(CameraPermissionStatus.authorized));
    } catch (e) {
      emit(const CameraPermissionError());
    }
  }

  Future<void> _onRefresh(
    CameraPermissionRefresh event,
    Emitter<CameraPermissionState> emit,
  ) async {
    try {
      final status = await checkPermissions();
      emit(CameraPermissionLoaded(status));
    } catch (e) {
      emit(const CameraPermissionError());
    }
  }

  Future<void> _onOpenSettings(
    CameraPermissionOpenSettings event,
    Emitter<CameraPermissionState> emit,
  ) async {
    await _permissionsService.openAppSettings();
  }

  /// Check the status of camera and microphone permissions.
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
