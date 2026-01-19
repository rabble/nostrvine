import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDivineCameraPlatform
    with MockPlatformInterfaceMixin
    implements DivineCameraPlatform {
  CameraState _state = const CameraState();
  bool _isRecording = false;
  void Function(VideoRecordingResult result)? _onRecordingAutoStopped;

  @override
  void Function(VideoRecordingResult result)? get onRecordingAutoStopped =>
      _onRecordingAutoStopped;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult result)? callback,
  ) {
    _onRecordingAutoStopped = callback;
  }

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
  }) async {
    return _state = CameraState(
      isInitialized: true,
      lens: lens,
      hasFlash: true,
      hasFrontCamera: true,
      hasBackCamera: true,
      maxZoomLevel: 10,
      textureId: 1,
      isFocusPointSupported: true,
      isExposurePointSupported: true,
    );
  }

  @override
  Future<void> disposeCamera() async {
    _state = const CameraState();
  }

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async {
    return true;
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    return true;
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    return true;
  }

  @override
  Future<bool> setZoomLevel(double level) async {
    return level >= 1.0 && level <= 10.0;
  }

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async {
    return _state = _state.copyWith(lens: lens);
  }

  @override
  Future<void> startRecording({Duration? maxDuration}) async {
    _isRecording = true;
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    return const VideoRecordingResult(
      filePath: '/test/video.mp4',
      durationMs: 5000,
      width: 1920,
      height: 1080,
    );
  }

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<CameraState> getCameraState() async {
    return _state;
  }

  @override
  Widget buildPreview(int textureId) {
    return Container();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialPlatform = DivineCameraPlatform.instance;

  group('DivineCameraPlatform', () {
    test('$MethodChannelDivineCamera is the default instance', () {
      expect(initialPlatform, isInstanceOf<MethodChannelDivineCamera>());
    });
  });

  group('DivineCamera', () {
    late MockDivineCameraPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockDivineCameraPlatform();
      DivineCameraPlatform.instance = mockPlatform;
    });

    test('getPlatformVersion returns expected value', () async {
      expect(await DivineCamera.instance.getPlatformVersion(), '42');
    });

    group('initialize', () {
      test('initializes with default lens (back)', () async {
        final state = await DivineCamera.instance.initialize();

        expect(state.isInitialized, isTrue);
        expect(state.lens, DivineCameraLens.back);
        expect(DivineCamera.instance.isInitialized, isTrue);
      });

      test('initializes with front camera', () async {
        final state = await DivineCamera.instance.initialize(
          lens: DivineCameraLens.front,
        );

        expect(state.isInitialized, isTrue);
        expect(state.lens, DivineCameraLens.front);
      });

      test('initializes with video quality', () async {
        final state = await DivineCamera.instance.initialize(
          videoQuality: DivineVideoQuality.uhd,
        );

        expect(state.isInitialized, isTrue);
      });

      test('initializes with enableScreenFlash true (default)', () async {
        final state = await DivineCamera.instance.initialize();

        expect(state.isInitialized, isTrue);
      });

      test('initializes with enableScreenFlash false', () async {
        final state = await DivineCamera.instance.initialize(
          enableScreenFlash: false,
        );

        expect(state.isInitialized, isTrue);
      });

      test('sets camera capabilities correctly', () async {
        final state = await DivineCamera.instance.initialize();

        expect(state.hasFlash, isTrue);
        expect(state.hasFrontCamera, isTrue);
        expect(state.hasBackCamera, isTrue);
        expect(state.minZoomLevel, 1.0);
        expect(state.maxZoomLevel, 10.0);
        expect(state.textureId, 1);
      });
    });

    group('dispose', () {
      test('disposes camera resources', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.dispose();

        expect(DivineCamera.instance.isInitialized, isFalse);
      });
    });

    group('flash mode', () {
      test('sets flash mode successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setFlashMode(
          DivineCameraFlashMode.on,
        );

        expect(success, isTrue);
        expect(DivineCamera.instance.state.flashMode, DivineCameraFlashMode.on);
      });

      test('cycles through flash modes', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.off);
        expect(
          DivineCamera.instance.state.flashMode,
          DivineCameraFlashMode.off,
        );

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.auto);
        expect(
          DivineCamera.instance.state.flashMode,
          DivineCameraFlashMode.auto,
        );

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.on);
        expect(DivineCamera.instance.state.flashMode, DivineCameraFlashMode.on);

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.torch);
        expect(
          DivineCamera.instance.state.flashMode,
          DivineCameraFlashMode.torch,
        );
      });
    });

    group('focus and exposure', () {
      test('sets focus point successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setFocusPoint(
          const Offset(0.5, 0.5),
        );

        expect(success, isTrue);
      });

      test('sets exposure point successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setExposurePoint(
          const Offset(0.3, 0.7),
        );

        expect(success, isTrue);
      });
    });

    group('zoom', () {
      test('sets zoom level successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setZoomLevel(2);

        expect(success, isTrue);
      });

      test('returns minZoomLevel and maxZoomLevel', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.minZoomLevel, 1.0);
        expect(DivineCamera.instance.maxZoomLevel, 10.0);
      });
    });

    group('switch camera', () {
      test('switches to front camera', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.switchCamera();

        expect(DivineCamera.instance.state.lens, DivineCameraLens.front);
      });

      test('switches back to rear camera', () async {
        await DivineCamera.instance.initialize(lens: DivineCameraLens.front);

        await DivineCamera.instance.switchCamera();

        expect(DivineCamera.instance.state.lens, DivineCameraLens.back);
      });

      test(
        'canSwitchCamera returns true when both cameras available',
        () async {
          await DivineCamera.instance.initialize();

          expect(DivineCamera.instance.canSwitchCamera, isTrue);
        },
      );
    });

    group('recording', () {
      test('starts recording', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.startRecording();

        expect(DivineCamera.instance.isRecording, isTrue);
      });

      test('stops recording and returns result', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.startRecording();

        final result = await DivineCamera.instance.stopRecording();

        expect(result, isNotNull);
        expect(result!.filePath, '/test/video.mp4');
        expect(result.durationMs, 5000);
        expect(result.width, 1920);
        expect(result.height, 1080);
        expect(DivineCamera.instance.isRecording, isFalse);
      });

      test('canRecord returns true when initialized', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.canRecord, isTrue);
      });

      test('canRecord returns false when not initialized', () async {
        await DivineCamera.instance.dispose();
        expect(DivineCamera.instance.canRecord, isFalse);
      });
    });

    group('state callbacks', () {
      test('onStateChanged is called when state changes', () async {
        CameraState? receivedState;
        DivineCamera.instance.onStateChanged = (state) {
          receivedState = state;
        };

        await DivineCamera.instance.initialize();

        expect(receivedState, isNotNull);
        expect(receivedState!.isInitialized, isTrue);
      });
    });
  });

  group('CameraState', () {
    test('creates default state', () {
      const state = CameraState();

      expect(state.isInitialized, isFalse);
      expect(state.isRecording, isFalse);
      expect(state.flashMode, DivineCameraFlashMode.off);
      expect(state.lens, DivineCameraLens.back);
      expect(state.zoomLevel, 1.0);
    });

    test('creates state from map', () {
      final map = {
        'isInitialized': true,
        'isRecording': true,
        'flashMode': 'torch',
        'lens': 'front',
        'zoomLevel': 2.5,
        'minZoomLevel': 1.0,
        'maxZoomLevel': 8.0,
        'aspectRatio': 1.777,
        'hasFlash': true,
        'hasFrontCamera': true,
        'hasBackCamera': true,
        'isFocusPointSupported': true,
        'isExposurePointSupported': true,
        'textureId': 42,
      };

      final state = CameraState.fromMap(map);

      expect(state.isInitialized, isTrue);
      expect(state.isRecording, isTrue);
      expect(state.flashMode, DivineCameraFlashMode.torch);
      expect(state.lens, DivineCameraLens.front);
      expect(state.zoomLevel, 2.5);
      expect(state.minZoomLevel, 1.0);
      expect(state.maxZoomLevel, 8.0);
      expect(state.aspectRatio, closeTo(1.777, 0.001));
      expect(state.hasFlash, isTrue);
      expect(state.hasFrontCamera, isTrue);
      expect(state.hasBackCamera, isTrue);
      expect(state.isFocusPointSupported, isTrue);
      expect(state.isExposurePointSupported, isTrue);
      expect(state.textureId, 42);
    });

    test('copyWith creates new state with updated values', () {
      const original = CameraState(
        isInitialized: true,
      );

      final copied = original.copyWith(
        flashMode: DivineCameraFlashMode.on,
        zoomLevel: 3,
      );

      expect(copied.isInitialized, isTrue);
      expect(copied.flashMode, DivineCameraFlashMode.on);
      expect(copied.zoomLevel, 3.0);
      // Original should be unchanged
      expect(original.flashMode, DivineCameraFlashMode.off);
      expect(original.zoomLevel, 1.0);
    });
  });

  group('VideoRecordingResult', () {
    test('creates result with all fields', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 10000,
        width: 1920,
        height: 1080,
      );

      expect(result.filePath, '/path/to/video.mp4');
      expect(result.durationMs, 10000);
      expect(result.width, 1920);
      expect(result.height, 1080);
    });

    test('creates result from map', () {
      final map = {
        'filePath': '/path/to/video.mp4',
        'durationMs': 5000,
        'width': 1280,
        'height': 720,
      };

      final result = VideoRecordingResult.fromMap(map);

      expect(result.filePath, '/path/to/video.mp4');
      expect(result.durationMs, 5000);
      expect(result.width, 1280);
      expect(result.height, 720);
    });

    test('duration getter returns Duration object', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 5000,
      );

      expect(result.duration, const Duration(milliseconds: 5000));
      expect(result.duration!.inSeconds, 5);
    });

    test('duration getter returns null when durationMs is null', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
      );

      expect(result.duration, isNull);
    });

    test('toMap converts result to map', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 3000,
        width: 1920,
        height: 1080,
      );

      final map = result.toMap();

      expect(map['filePath'], '/path/to/video.mp4');
      expect(map['durationMs'], 3000);
      expect(map['width'], 1920);
      expect(map['height'], 1080);
    });
  });

  group('DivineCameraFlashMode', () {
    test('toNativeString returns correct values', () {
      expect(DivineCameraFlashMode.off.toNativeString(), 'off');
      expect(DivineCameraFlashMode.auto.toNativeString(), 'auto');
      expect(DivineCameraFlashMode.on.toNativeString(), 'on');
      expect(DivineCameraFlashMode.torch.toNativeString(), 'torch');
    });

    test('fromNativeString creates correct modes', () {
      expect(
        DivineCameraFlashMode.fromNativeString('off'),
        DivineCameraFlashMode.off,
      );
      expect(
        DivineCameraFlashMode.fromNativeString('auto'),
        DivineCameraFlashMode.auto,
      );
      expect(
        DivineCameraFlashMode.fromNativeString('on'),
        DivineCameraFlashMode.on,
      );
      expect(
        DivineCameraFlashMode.fromNativeString('torch'),
        DivineCameraFlashMode.torch,
      );
    });

    test('fromNativeString defaults to off for unknown values', () {
      expect(
        DivineCameraFlashMode.fromNativeString('unknown'),
        DivineCameraFlashMode.off,
      );
      expect(
        DivineCameraFlashMode.fromNativeString(''),
        DivineCameraFlashMode.off,
      );
    });
  });

  group('DivineCameraLens', () {
    test('toNativeString returns correct values', () {
      expect(DivineCameraLens.back.toNativeString(), 'back');
      expect(DivineCameraLens.front.toNativeString(), 'front');
    });

    test('fromNativeString creates correct lens', () {
      expect(DivineCameraLens.fromNativeString('back'), DivineCameraLens.back);
      expect(
        DivineCameraLens.fromNativeString('front'),
        DivineCameraLens.front,
      );
    });

    test('fromNativeString defaults to back for unknown values', () {
      expect(
        DivineCameraLens.fromNativeString('unknown'),
        DivineCameraLens.back,
      );
      expect(DivineCameraLens.fromNativeString(''), DivineCameraLens.back);
    });
  });

  group('DivineVideoQuality', () {
    test('value returns correct strings', () {
      expect(DivineVideoQuality.sd.value, 'sd');
      expect(DivineVideoQuality.hd.value, 'hd');
      expect(DivineVideoQuality.fhd.value, 'fhd');
      expect(DivineVideoQuality.uhd.value, 'uhd');
      expect(DivineVideoQuality.highest.value, 'highest');
      expect(DivineVideoQuality.lowest.value, 'lowest');
    });
  });
}
