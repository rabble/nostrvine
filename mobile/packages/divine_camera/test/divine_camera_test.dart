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
    bool mirrorFrontCameraOutput = false,
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
      availableLenses: const [
        DivineCameraLens.front,
        DivineCameraLens.frontUltraWide,
        DivineCameraLens.back,
        DivineCameraLens.ultraWide,
        DivineCameraLens.telephoto,
      ],
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
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    _isRecording = true;
    return true;
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    return const VideoRecordingResult(
      filePath: '/test/video.mp4',
      durationMs: 5000,
      width: 1080,
      height: 1920,
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

      test('mirrorFrontCameraOutput defaults to false', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.mirrorFrontCameraOutput, isFalse);
      });

      test('mirrorFrontCameraOutput reflects initialization value', () async {
        await DivineCamera.instance.initialize(
          mirrorFrontCameraOutput: true,
        );

        expect(DivineCamera.instance.mirrorFrontCameraOutput, isTrue);
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

    group('setLens', () {
      test('switches to specific lens', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.ultraWide,
        );

        expect(result, isTrue);
        expect(DivineCamera.instance.state.lens, DivineCameraLens.ultraWide);
      });

      test('returns true when already on requested lens', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.back,
        );

        expect(result, isTrue);
        expect(DivineCamera.instance.state.lens, DivineCameraLens.back);
      });

      test('returns false when lens not available', () async {
        await DivineCamera.instance.initialize();

        // macro is not in availableLenses in the mock
        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.macro,
        );

        expect(result, isFalse);
        // Lens should not have changed
        expect(DivineCamera.instance.state.lens, DivineCameraLens.back);
      });

      test('switches to frontUltraWide lens', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.frontUltraWide,
        );

        expect(result, isTrue);
        expect(
          DivineCamera.instance.state.lens,
          DivineCameraLens.frontUltraWide,
        );
      });
    });

    group('hasFrontUltraWideCamera', () {
      test('returns true when frontUltraWide is in availableLenses', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.state.hasFrontUltraWideCamera, isTrue);
      });

      test('returns false when frontUltraWide is not available', () async {
        // Use single camera mock which doesn't have frontUltraWide
        final singleCameraMock = _SingleCameraMock();
        DivineCameraPlatform.instance = singleCameraMock;

        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.state.hasFrontUltraWideCamera, isFalse);
      });
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
        expect(result.width, 1080);
        expect(result.height, 1920);
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

  group('CameraState additional tests', () {
    test('toMap converts state to map', () {
      const state = CameraState(
        isInitialized: true,
        isRecording: true,
        flashMode: DivineCameraFlashMode.torch,
        lens: DivineCameraLens.front,
        zoomLevel: 2,
        maxZoomLevel: 8,
        aspectRatio: 1.777,
        hasFlash: true,
        hasFrontCamera: true,
        hasBackCamera: true,
        isFocusPointSupported: true,
        isExposurePointSupported: true,
        textureId: 42,
      );

      final map = state.toMap();

      expect(map['isInitialized'], isTrue);
      expect(map['isRecording'], isTrue);
      expect(map['isSwitchingCamera'], isFalse);
      expect(map['flashMode'], 'torch');
      expect(map['lens'], 'front');
      expect(map['zoomLevel'], 2.0);
      expect(map['minZoomLevel'], 1.0);
      expect(map['maxZoomLevel'], 8.0);
      expect(map['aspectRatio'], closeTo(1.777, 0.001));
      expect(map['hasFlash'], isTrue);
      expect(map['hasFrontCamera'], isTrue);
      expect(map['hasBackCamera'], isTrue);
      expect(map['isFocusPointSupported'], isTrue);
      expect(map['isExposurePointSupported'], isTrue);
      expect(map['textureId'], 42);
    });

    test('toString returns formatted string', () {
      const state = CameraState(
        isInitialized: true,
        textureId: 1,
      );

      final str = state.toString();

      expect(str, contains('CameraState'));
      expect(str, contains('isInitialized: true'));
      expect(str, contains('isRecording: false'));
      expect(str, contains('lens: DivineCameraLens.back'));
      expect(str, contains('textureId: 1'));
    });

    test('props returns correct list of properties', () {
      const state = CameraState(
        isInitialized: true,
        maxZoomLevel: 8,
        aspectRatio: 1.777,
        hasFlash: true,
        hasFrontCamera: true,
        hasBackCamera: true,
        textureId: 1,
      );

      final props = state.props;

      expect(props.length, 17);
      expect(props[0], isTrue); // isInitialized
      expect(props[1], isFalse); // isRecording
      expect(props[4], DivineCameraLens.back); // lens
      expect(props[14], 1); // textureId
    });

    test('equality works correctly', () {
      const state1 = CameraState(isInitialized: true, textureId: 1);
      const state2 = CameraState(isInitialized: true, textureId: 1);
      const state3 = CameraState(isInitialized: true, textureId: 2);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('copyWith with all parameters', () {
      const original = CameraState();

      final copied = original.copyWith(
        isInitialized: true,
        isRecording: true,
        isSwitchingCamera: true,
        flashMode: DivineCameraFlashMode.torch,
        lens: DivineCameraLens.front,
        zoomLevel: 5,
        minZoomLevel: 1,
        maxZoomLevel: 10,
        aspectRatio: 1.5,
        hasFlash: true,
        hasFrontCamera: true,
        hasBackCamera: true,
        isFocusPointSupported: true,
        isExposurePointSupported: true,
        textureId: 99,
      );

      expect(copied.isInitialized, isTrue);
      expect(copied.isRecording, isTrue);
      expect(copied.isSwitchingCamera, isTrue);
      expect(copied.flashMode, DivineCameraFlashMode.torch);
      expect(copied.lens, DivineCameraLens.front);
      expect(copied.zoomLevel, 5.0);
      expect(copied.minZoomLevel, 1.0);
      expect(copied.maxZoomLevel, 10.0);
      expect(copied.aspectRatio, 1.5);
      expect(copied.hasFlash, isTrue);
      expect(copied.hasFrontCamera, isTrue);
      expect(copied.hasBackCamera, isTrue);
      expect(copied.isFocusPointSupported, isTrue);
      expect(copied.isExposurePointSupported, isTrue);
      expect(copied.textureId, 99);
    });

    test('fromMap with missing values uses defaults', () {
      final state = CameraState.fromMap(const {});

      expect(state.isInitialized, isFalse);
      expect(state.isRecording, isFalse);
      expect(state.flashMode, DivineCameraFlashMode.off);
      expect(state.lens, DivineCameraLens.back);
      expect(state.zoomLevel, 1.0);
      expect(state.aspectRatio, closeTo(9 / 16, 0.01));
      expect(state.textureId, isNull);
    });

    test('fromMap with isSwitchingCamera', () {
      final state = CameraState.fromMap(const {'isSwitchingCamera': true});

      expect(state.isSwitchingCamera, isTrue);
    });
  });

  group('VideoRecordingResult additional tests', () {
    test('toString returns formatted string', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 5000,
        width: 1920,
        height: 1080,
      );

      final str = result.toString();

      expect(str, contains('VideoRecordingResult'));
      expect(str, contains('filePath: /path/to/video.mp4'));
      expect(str, contains('durationMs: 5000'));
      expect(str, contains('width: 1920'));
      expect(str, contains('height: 1080'));
    });

    test('props returns correct list of properties', () {
      const result = VideoRecordingResult(
        filePath: '/test.mp4',
        durationMs: 1000,
        width: 1280,
        height: 720,
      );

      final props = result.props;

      expect(props.length, 4);
      expect(props[0], '/test.mp4');
      expect(props[1], 1000);
      expect(props[2], 1280);
      expect(props[3], 720);
    });

    test('equality works correctly', () {
      const result1 = VideoRecordingResult(
        filePath: '/test.mp4',
        durationMs: 1000,
      );
      const result2 = VideoRecordingResult(
        filePath: '/test.mp4',
        durationMs: 1000,
      );
      const result3 = VideoRecordingResult(
        filePath: '/other.mp4',
        durationMs: 1000,
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('file getter returns File object', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
      );

      expect(result.file.path, '/path/to/video.mp4');
    });
  });

  group('DivineCameraLens', () {
    test('opposite returns the other lens', () {
      expect(DivineCameraLens.back.opposite, DivineCameraLens.front);
      expect(DivineCameraLens.front.opposite, DivineCameraLens.back);
    });
  });

  group('DivineCamera additional tests', () {
    late MockDivineCameraPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockDivineCameraPlatform();
      DivineCameraPlatform.instance = mockPlatform;
    });

    test('onRecordingAutoStopped callback is invoked', () async {
      VideoRecordingResult? receivedResult;
      DivineCamera.instance.onRecordingAutoStopped = (result) {
        receivedResult = result;
      };

      await DivineCamera.instance.initialize();

      // Simulate auto-stop from platform
      const autoStopResult = VideoRecordingResult(
        filePath: '/auto/stopped.mp4',
        durationMs: 30000,
      );
      mockPlatform.onRecordingAutoStopped?.call(autoStopResult);

      expect(receivedResult, isNotNull);
      expect(receivedResult!.filePath, '/auto/stopped.mp4');
      expect(DivineCamera.instance.isRecording, isFalse);
    });

    test('setFocusPoint returns false when not supported', () async {
      // Create mock that doesn't support focus
      final noFocusMock = _NoFocusSupportMock();
      DivineCameraPlatform.instance = noFocusMock;

      await DivineCamera.instance.initialize();

      final result = await DivineCamera.instance.setFocusPoint(
        const Offset(0.5, 0.5),
      );

      expect(result, isFalse);
    });

    test('setExposurePoint returns false when not supported', () async {
      // Create mock that doesn't support exposure
      final noExposureMock = _NoExposureSupportMock();
      DivineCameraPlatform.instance = noExposureMock;

      await DivineCamera.instance.initialize();

      final result = await DivineCamera.instance.setExposurePoint(
        const Offset(0.5, 0.5),
      );

      expect(result, isFalse);
    });

    test('setZoomLevel clamps level within bounds', () async {
      await DivineCamera.instance.initialize();

      // Try to set zoom below min
      await DivineCamera.instance.setZoomLevel(0.1);
      expect(DivineCamera.instance.zoomLevel, 1.0);

      // Try to set zoom above max
      await DivineCamera.instance.setZoomLevel(100);
      expect(DivineCamera.instance.zoomLevel, 10.0);
    });

    test('switchCamera returns false when cannot switch', () async {
      // Create mock with only one camera
      final singleCameraMock = _SingleCameraMock();
      DivineCameraPlatform.instance = singleCameraMock;

      await DivineCamera.instance.initialize();

      final result = await DivineCamera.instance.switchCamera();

      expect(result, isFalse);
    });

    test('startRecording does nothing when cannot record', () async {
      await DivineCamera.instance.dispose(); // Not initialized

      await DivineCamera.instance.startRecording();

      expect(DivineCamera.instance.isRecording, isFalse);
    });

    test('startRecording with maxDuration', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.startRecording(
        maxDuration: const Duration(seconds: 30),
      );

      expect(DivineCamera.instance.isRecording, isTrue);
    });

    test('startRecording with useCache false', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.startRecording(useCache: false);

      expect(DivineCamera.instance.isRecording, isTrue);
    });

    test('stopRecording returns null when not recording', () async {
      await DivineCamera.instance.initialize();
      // Don't start recording

      final result = await DivineCamera.instance.stopRecording();

      expect(result, isNull);
    });

    test('handleAppLifecycleState paused calls pausePreview', () async {
      await DivineCamera.instance.initialize();

      // pausePreview is called - no exception means it worked
      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.paused,
      );

      // Camera should still be initialized after pause
      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState inactive calls pausePreview', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.inactive,
      );

      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState detached calls pausePreview', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.detached,
      );

      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState hidden calls pausePreview', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.hidden,
      );

      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState resumed updates state', () async {
      await DivineCamera.instance.initialize();

      // Set callback AFTER initialize to test that resumed triggers it
      CameraState? receivedState;
      DivineCamera.instance.onStateChanged = (state) {
        receivedState = state;
      };

      // Verify callback hasn't been called yet (since we set it after init)
      expect(receivedState, isNull);

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.resumed,
      );

      // Now onStateChanged should be called by handleAppLifecycleState
      expect(receivedState, isNotNull);
      expect(receivedState!.isInitialized, isTrue);
    });

    test('handleAppLifecycleState does nothing when not initialized', () async {
      await DivineCamera.instance.dispose();

      CameraState? receivedState;
      DivineCamera.instance.onStateChanged = (state) {
        receivedState = state;
      };

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.paused,
      );

      // onStateChanged should NOT be called since camera is not initialized
      expect(receivedState, isNull);
      expect(DivineCamera.instance.isInitialized, isFalse);
    });

    test('getter properties return correct values', () async {
      await DivineCamera.instance.initialize();

      expect(DivineCamera.instance.cameraAspectRatio, isA<double>());
      expect(DivineCamera.instance.hasFlash, isTrue);
      expect(DivineCamera.instance.hasFrontCamera, isTrue);
      expect(DivineCamera.instance.hasBackCamera, isTrue);
      expect(DivineCamera.instance.isFocusPointSupported, isTrue);
      expect(DivineCamera.instance.isExposurePointSupported, isTrue);
      expect(DivineCamera.instance.isSwitchingCamera, isFalse);
      expect(DivineCamera.instance.textureId, 1);
      expect(DivineCamera.instance.lens, DivineCameraLens.back);
    });

    test('dispose clears callbacks', () async {
      DivineCamera.instance.onStateChanged = (_) {};
      DivineCamera.instance.onRecordingAutoStopped = (_) {};

      await DivineCamera.instance.initialize();
      await DivineCamera.instance.dispose();

      expect(DivineCamera.instance.onStateChanged, isNull);
      expect(DivineCamera.instance.onRecordingAutoStopped, isNull);
    });
  });

  group('CameraLensMetadata', () {
    test('creates metadata with required lensType', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      expect(metadata.lensType, 'back');
      expect(metadata.focalLength, isNull);
      expect(metadata.hasOpticalStabilization, isFalse);
      expect(metadata.isLogicalCamera, isFalse);
      expect(metadata.physicalCameraIds, isEmpty);
    });

    test('creates metadata with all fields', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        focalLength: 4.5,
        focalLengthEquivalent35mm: 26,
        aperture: 1.8,
        sensorWidth: 6.17,
        sensorHeight: 4.55,
        pixelArrayWidth: 4032,
        pixelArrayHeight: 3024,
        minFocusDistance: 10,
        fieldOfView: 80,
        hasOpticalStabilization: true,
        isLogicalCamera: true,
        physicalCameraIds: ['cam0', 'cam1'],
      );

      expect(metadata.lensType, 'back');
      expect(metadata.focalLength, 4.5);
      expect(metadata.focalLengthEquivalent35mm, 26.0);
      expect(metadata.aperture, 1.8);
      expect(metadata.sensorWidth, 6.17);
      expect(metadata.sensorHeight, 4.55);
      expect(metadata.pixelArrayWidth, 4032);
      expect(metadata.pixelArrayHeight, 3024);
      expect(metadata.minFocusDistance, 10.0);
      expect(metadata.fieldOfView, 80.0);
      expect(metadata.hasOpticalStabilization, isTrue);
      expect(metadata.isLogicalCamera, isTrue);
      expect(metadata.physicalCameraIds, ['cam0', 'cam1']);
    });

    test('fromMap creates metadata from map', () {
      final map = {
        'lensType': 'ultraWide',
        'focalLength': 2.5,
        'focalLengthEquivalent35mm': 13.0,
        'aperture': 2.2,
        'sensorWidth': 5.0,
        'sensorHeight': 3.75,
        'pixelArrayWidth': 3024,
        'pixelArrayHeight': 2268,
        'minFocusDistance': 25.0,
        'fieldOfView': 120.0,
        'hasOpticalStabilization': false,
        'isLogicalCamera': false,
        'physicalCameraIds': <String>[],
      };

      final metadata = CameraLensMetadata.fromMap(map);

      expect(metadata.lensType, 'ultraWide');
      expect(metadata.focalLength, 2.5);
      expect(metadata.focalLengthEquivalent35mm, 13.0);
      expect(metadata.aperture, 2.2);
      expect(metadata.sensorWidth, 5.0);
      expect(metadata.sensorHeight, 3.75);
      expect(metadata.pixelArrayWidth, 3024);
      expect(metadata.pixelArrayHeight, 2268);
      expect(metadata.minFocusDistance, 25.0);
      expect(metadata.fieldOfView, 120.0);
      expect(metadata.hasOpticalStabilization, isFalse);
      expect(metadata.isLogicalCamera, isFalse);
      expect(metadata.physicalCameraIds, isEmpty);
    });

    test('fromMap with empty map uses defaults', () {
      final metadata = CameraLensMetadata.fromMap(const {});

      expect(metadata.lensType, 'unknown');
      expect(metadata.focalLength, isNull);
      expect(metadata.hasOpticalStabilization, isFalse);
      expect(metadata.isLogicalCamera, isFalse);
      expect(metadata.physicalCameraIds, isEmpty);
    });

    test('fromMap handles physicalCameraIds with mixed types', () {
      final map = {
        'lensType': 'back',
        'physicalCameraIds': ['cam0', 123, 'cam1', null],
      };

      final metadata = CameraLensMetadata.fromMap(map);

      expect(metadata.physicalCameraIds, ['cam0', 'cam1']);
    });

    test('toMap converts metadata to map', () {
      const metadata = CameraLensMetadata(
        lensType: 'front',
        focalLength: 3,
        focalLengthEquivalent35mm: 22,
        aperture: 2,
        sensorWidth: 4,
        sensorHeight: 3,
        pixelArrayWidth: 2048,
        pixelArrayHeight: 1536,
        minFocusDistance: 5,
        fieldOfView: 90,
        hasOpticalStabilization: true,
        isLogicalCamera: true,
        physicalCameraIds: ['a', 'b'],
      );

      final map = metadata.toMap();

      expect(map['lensType'], 'front');
      expect(map['focalLength'], 3.0);
      expect(map['focalLengthEquivalent35mm'], 22.0);
      expect(map['aperture'], 2.0);
      expect(map['sensorWidth'], 4.0);
      expect(map['sensorHeight'], 3.0);
      expect(map['pixelArrayWidth'], 2048);
      expect(map['pixelArrayHeight'], 1536);
      expect(map['minFocusDistance'], 5.0);
      expect(map['fieldOfView'], 90.0);
      expect(map['hasOpticalStabilization'], isTrue);
      expect(map['isLogicalCamera'], isTrue);
      expect(map['physicalCameraIds'], ['a', 'b']);
    });

    test('megapixels returns correct value', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        pixelArrayWidth: 4000,
        pixelArrayHeight: 3000,
      );

      expect(metadata.megapixels, closeTo(12.0, 0.01));
    });

    test('megapixels returns null when dimensions missing', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      expect(metadata.megapixels, isNull);
    });

    test('minFocusDistanceCm returns correct value', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        minFocusDistance: 10, // 10 diopters = 10cm
      );

      expect(metadata.minFocusDistanceCm, closeTo(10.0, 0.01));
    });

    test('minFocusDistanceCm returns null for fixed focus', () {
      const metadata = CameraLensMetadata(
        lensType: 'front',
        minFocusDistance: 0,
      );

      expect(metadata.minFocusDistanceCm, isNull);
    });

    test('minFocusDistanceCm returns null when not set', () {
      const metadata = CameraLensMetadata(lensType: 'front');

      expect(metadata.minFocusDistanceCm, isNull);
    });

    test('isMacroCapable returns true for close focus', () {
      const metadata = CameraLensMetadata(
        lensType: 'ultraWide',
        minFocusDistance: 50, // 50 diopters = 2cm
      );

      expect(metadata.isMacroCapable, isTrue);
    });

    test('isMacroCapable returns false for normal focus', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        minFocusDistance: 10, // 10 diopters = 10cm
      );

      expect(metadata.isMacroCapable, isFalse);
    });

    test('isMacroCapable returns false when focus not set', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      expect(metadata.isMacroCapable, isFalse);
    });

    test('toString returns formatted string', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        focalLength: 4.5,
        aperture: 1.8,
        pixelArrayWidth: 4000,
        pixelArrayHeight: 3000,
      );

      final str = metadata.toString();

      expect(str, contains('CameraLensMetadata'));
      expect(str, contains('lensType: back'));
      expect(str, contains('focalLength: 4.5mm'));
      expect(str, contains('aperture: f/1.8'));
      expect(str, contains('12.0MP'));
    });

    test('props returns correct list', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
      );

      final props = metadata.props;

      expect(props.length, 20);
      expect(props[0], 'back');
    });

    test('equality works correctly', () {
      const meta1 = CameraLensMetadata(lensType: 'back', focalLength: 4.5);
      const meta2 = CameraLensMetadata(lensType: 'back', focalLength: 4.5);
      const meta3 = CameraLensMetadata(lensType: 'front', focalLength: 4.5);

      expect(meta1, equals(meta2));
      expect(meta1, isNot(equals(meta3)));
    });
  });

  group('CameraState with currentLensMetadata', () {
    test('fromMap parses currentLensMetadata', () {
      final map = {
        'isInitialized': true,
        'currentLensMetadata': {
          'lensType': 'back',
          'focalLength': 4.5,
          'aperture': 1.8,
        },
      };

      final state = CameraState.fromMap(map);

      expect(state.currentLensMetadata, isNotNull);
      expect(state.currentLensMetadata!.lensType, 'back');
      expect(state.currentLensMetadata!.focalLength, 4.5);
      expect(state.currentLensMetadata!.aperture, 1.8);
    });

    test('fromMap handles null currentLensMetadata', () {
      final map = {
        'isInitialized': true,
        'currentLensMetadata': null,
      };

      final state = CameraState.fromMap(map);

      expect(state.currentLensMetadata, isNull);
    });

    test('fromMap handles missing currentLensMetadata', () {
      final map = {
        'isInitialized': true,
      };

      final state = CameraState.fromMap(map);

      expect(state.currentLensMetadata, isNull);
    });
  });
}

/// Mock that doesn't support focus point
class _NoFocusSupportMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
  }) async {
    return const CameraState(
      isInitialized: true,
      isExposurePointSupported: true,
    );
  }
}

/// Mock that doesn't support exposure point
class _NoExposureSupportMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
  }) async {
    return const CameraState(
      isInitialized: true,
      isFocusPointSupported: true,
    );
  }
}

/// Mock with only one camera (cannot switch)
class _SingleCameraMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
  }) async {
    return const CameraState(
      isInitialized: true,
      hasBackCamera: true,
    );
  }
}
