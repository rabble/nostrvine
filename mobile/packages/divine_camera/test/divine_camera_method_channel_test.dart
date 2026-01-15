import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDivineCamera();
  const channel = MethodChannel('divine_camera');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (MethodCall methodCall) async {
            final args = methodCall.arguments as Map<dynamic, dynamic>?;
            switch (methodCall.method) {
              case 'getPlatformVersion':
                return 'Android 14';
              case 'initializeCamera':
                return {
                  'isInitialized': true,
                  'isRecording': false,
                  'flashMode': 'off',
                  'lens': args?['lens'] ?? 'back',
                  'zoomLevel': 1.0,
                  'minZoomLevel': 1.0,
                  'maxZoomLevel': 8.0,
                  'aspectRatio': 1.777,
                  'hasFlash': true,
                  'hasFrontCamera': true,
                  'hasBackCamera': true,
                  'isFocusPointSupported': true,
                  'isExposurePointSupported': true,
                  'textureId': 1,
                };
              case 'disposeCamera':
                return null;
              case 'setFlashMode':
                return true;
              case 'setFocusPoint':
                return true;
              case 'setExposurePoint':
                return true;
              case 'setZoomLevel':
                return true;
              case 'switchCamera':
                return {
                  'isInitialized': true,
                  'isRecording': false,
                  'flashMode': 'off',
                  'lens': args?['lens'] ?? 'front',
                  'zoomLevel': 1.0,
                  'minZoomLevel': 1.0,
                  'maxZoomLevel': 8.0,
                  'aspectRatio': 1.777,
                  'hasFlash': true,
                  'hasFrontCamera': true,
                  'hasBackCamera': true,
                  'isFocusPointSupported': true,
                  'isExposurePointSupported': true,
                  'textureId': 1,
                };
              case 'startRecording':
                return null;
              case 'stopRecording':
                return {
                  'filePath': '/path/to/video.mp4',
                  'durationMs': 5000,
                  'width': 1920,
                  'height': 1080,
                };
              case 'pausePreview':
                return null;
              case 'resumePreview':
                return null;
              case 'getCameraState':
                return {
                  'isInitialized': true,
                  'isRecording': false,
                  'flashMode': 'off',
                  'lens': 'back',
                  'zoomLevel': 1.0,
                  'minZoomLevel': 1.0,
                  'maxZoomLevel': 8.0,
                  'aspectRatio': 1.777,
                  'hasFlash': true,
                  'hasFrontCamera': true,
                  'hasBackCamera': true,
                  'isFocusPointSupported': true,
                  'isExposurePointSupported': true,
                  'textureId': 1,
                };
              default:
                return null;
            }
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MethodChannelDivineCamera', () {
    test('getPlatformVersion returns platform version', () async {
      expect(await platform.getPlatformVersion(), 'Android 14');
    });

    test('initializeCamera returns CameraState', () async {
      final state = await platform.initializeCamera();

      expect(state.isInitialized, isTrue);
      expect(state.hasFlash, isTrue);
      expect(state.hasFrontCamera, isTrue);
      expect(state.hasBackCamera, isTrue);
      expect(state.textureId, 1);
    });

    test('initializeCamera with front lens', () async {
      final state = await platform.initializeCamera(
        lens: DivineCameraLens.front,
      );

      expect(state.lens, DivineCameraLens.front);
    });

    test('disposeCamera completes without error', () async {
      await expectLater(platform.disposeCamera(), completes);
    });

    test('setFlashMode returns true', () async {
      final result = await platform.setFlashMode(DivineCameraFlashMode.torch);

      expect(result, isTrue);
    });

    test('setFocusPoint returns true', () async {
      final result = await platform.setFocusPoint(const Offset(0.5, 0.5));

      expect(result, isTrue);
    });

    test('setExposurePoint returns true', () async {
      final result = await platform.setExposurePoint(const Offset(0.3, 0.7));

      expect(result, isTrue);
    });

    test('setZoomLevel returns true', () async {
      final result = await platform.setZoomLevel(2.5);

      expect(result, isTrue);
    });

    test('switchCamera returns updated CameraState', () async {
      final state = await platform.switchCamera(DivineCameraLens.front);

      expect(state.lens, DivineCameraLens.front);
    });

    test('startRecording completes without error', () async {
      await expectLater(platform.startRecording(), completes);
    });

    test('stopRecording returns VideoRecordingResult', () async {
      final result = await platform.stopRecording();

      expect(result, isNotNull);
      expect(result!.filePath, '/path/to/video.mp4');
      expect(result.durationMs, 5000);
      expect(result.width, 1920);
      expect(result.height, 1080);
    });

    test('pausePreview completes without error', () async {
      await expectLater(platform.pausePreview(), completes);
    });

    test('resumePreview completes without error', () async {
      await expectLater(platform.resumePreview(), completes);
    });

    test('getCameraState returns CameraState', () async {
      final state = await platform.getCameraState();

      expect(state.isInitialized, isTrue);
      expect(state.lens, DivineCameraLens.back);
    });
  });
}
