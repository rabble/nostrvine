import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/services/video_recorder/camera/camera_mobile_service.dart';

class _FakeCameraPlatform extends DivineCameraPlatform {
  bool shouldFail = true;

  @override
  void Function(VideoRecordingResult result)? onRecordingAutoStopped;

  @override
  void Function(RemoteRecordTrigger trigger)? onRemoteRecordTrigger;

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    if (shouldFail) throw StateError('camera unavailable');
    return const CameraState(isInitialized: true, textureId: 1);
  }

  @override
  Future<void> disposeCamera() async {}
}

void main() {
  group(CameraMobileService, () {
    final initialPlatform = DivineCameraPlatform.instance;
    late _FakeCameraPlatform platform;
    late List<bool?> rebuildRequests;
    late CameraMobileService service;

    setUp(() async {
      platform = _FakeCameraPlatform();
      DivineCameraPlatform.instance = platform;
      await DivineCamera.instance.dispose();
      rebuildRequests = [];
      service = CameraMobileService(
        onUpdateState: ({forceCameraRebuild}) {
          rebuildRequests.add(forceCameraRebuild);
        },
        onAutoStopped: (_) {},
      );
    });

    tearDown(() async {
      await DivineCamera.instance.dispose();
      DivineCameraPlatform.instance = initialPlatform;
    });

    test('rethrows initialization failures after updating state', () async {
      await expectLater(service.initialize(), throwsStateError);

      expect(service.isInitialized, isFalse);
      expect(
        service.initializationError,
        CameraInitializationError.failed,
      );
      expect(rebuildRequests, [isTrue]);
    });

    test('clears a previous failure when initialization is retried', () async {
      await expectLater(service.initialize(), throwsStateError);
      platform.shouldFail = false;

      await service.initialize();

      expect(service.isInitialized, isTrue);
      expect(service.initializationError, isNull);
      expect(rebuildRequests, [isTrue, isTrue]);
    });
  });
}
