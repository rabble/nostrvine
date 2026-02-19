import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelDivineCamera platform;
  const channel = MethodChannel('divine_camera');

  setUp(() {
    platform = MethodChannelDivineCamera();
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
                  'availableLenses': [
                    'front',
                    'back',
                    'ultraWide',
                    'telephoto',
                  ],
                };
              case 'disposeCamera':
                return null;
              case 'setFlashMode':
                return true;
              case 'setFocusPoint':
                return true;
              case 'setExposurePoint':
                return true;
              case 'cancelFocusAndMetering':
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
                  'availableLenses': [
                    'front',
                    'back',
                    'ultraWide',
                    'telephoto',
                  ],
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
                  'availableLenses': [
                    'front',
                    'back',
                    'ultraWide',
                    'telephoto',
                  ],
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

    test('initializeCamera with video quality', () async {
      final state = await platform.initializeCamera(
        videoQuality: DivineVideoQuality.uhd,
      );

      expect(state.isInitialized, isTrue);
    });

    test('initializeCamera with enableScreenFlash false', () async {
      final state = await platform.initializeCamera(
        enableScreenFlash: false,
      );

      expect(state.isInitialized, isTrue);
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

    test('cancelFocusAndMetering returns true', () async {
      final result = await platform.cancelFocusAndMetering();

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

    test('switchCamera to ultraWide returns correct lens', () async {
      final state = await platform.switchCamera(DivineCameraLens.ultraWide);

      expect(state.lens, DivineCameraLens.ultraWide);
    });

    test('switchCamera to telephoto returns correct lens', () async {
      final state = await platform.switchCamera(DivineCameraLens.telephoto);

      expect(state.lens, DivineCameraLens.telephoto);
    });

    test('initializeCamera returns availableLenses', () async {
      final state = await platform.initializeCamera();

      expect(state.availableLenses, isNotEmpty);
      expect(state.availableLenses, contains(DivineCameraLens.front));
      expect(state.availableLenses, contains(DivineCameraLens.back));
      expect(state.availableLenses, contains(DivineCameraLens.ultraWide));
      expect(state.availableLenses, contains(DivineCameraLens.telephoto));
    });

    test(
      'CameraState hasUltraWideCamera returns true when available',
      () async {
        final state = await platform.initializeCamera();

        expect(state.hasUltraWideCamera, isTrue);
      },
    );

    test(
      'CameraState hasTelephotoCamera returns true when available',
      () async {
        final state = await platform.initializeCamera();

        expect(state.hasTelephotoCamera, isTrue);
      },
    );

    test(
      'CameraState hasMacroCamera returns false when not available',
      () async {
        final state = await platform.initializeCamera();

        expect(state.hasMacroCamera, isFalse);
      },
    );

    test('CameraState availableBackLenses filters front camera', () async {
      final state = await platform.initializeCamera();

      expect(
        state.availableBackLenses,
        isNot(contains(DivineCameraLens.front)),
      );
      expect(state.availableBackLenses, contains(DivineCameraLens.back));
      expect(state.availableBackLenses, contains(DivineCameraLens.ultraWide));
    });

    test(
      'CameraState availableFrontLenses returns only front cameras',
      () async {
        final state = await platform.initializeCamera();

        expect(state.availableFrontLenses, contains(DivineCameraLens.front));
        expect(
          state.availableFrontLenses,
          isNot(contains(DivineCameraLens.back)),
        );
        expect(
          state.availableFrontLenses,
          isNot(contains(DivineCameraLens.ultraWide)),
        );
      },
    );

    test('startRecording completes without error', () async {
      await expectLater(platform.startRecording(), completes);
    });

    test('startRecording with maxDuration', () async {
      await expectLater(
        platform.startRecording(maxDuration: const Duration(seconds: 30)),
        completes,
      );
    });

    test('startRecording with useCache false', () async {
      await expectLater(
        platform.startRecording(useCache: false),
        completes,
      );
    });

    test('startRecording with outputDirectory', () async {
      await expectLater(
        platform.startRecording(outputDirectory: '/custom/path'),
        completes,
      );
    });

    test('startRecording returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (MethodCall methodCall) async {
              if (methodCall.method == 'startRecording') {
                throw PlatformException(
                  code: 'RECORD_START_ERROR',
                  message: 'Recording failed to start',
                );
              }
              return null;
            },
          );

      final result = await platform.startRecording();
      expect(result, isFalse);
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

    test('buildPreview returns Texture widget', () {
      final widget = platform.buildPreview(1);

      expect(widget, isA<Texture>());
      expect((widget as Texture).textureId, 1);
    });

    test('onRecordingAutoStopped getter and setter work', () {
      void Function(VideoRecordingResult)? callback;
      callback = (result) {};

      platform.onRecordingAutoStopped = callback;
      expect(platform.onRecordingAutoStopped, callback);

      platform.onRecordingAutoStopped = null;
      expect(platform.onRecordingAutoStopped, isNull);
    });
  });

  group('MethodChannelDivineCamera error handling', () {
    test('initializeCamera throws when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'initializeCamera') {
              return null;
            }
            return null;
          });

      await expectLater(
        platform.initializeCamera(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('switchCamera throws when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'switchCamera') {
              return null;
            }
            return null;
          });

      await expectLater(
        platform.switchCamera(DivineCameraLens.front),
        throwsA(isA<PlatformException>()),
      );
    });

    test('getCameraState throws when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'getCameraState') {
              return null;
            }
            return null;
          });

      await expectLater(
        platform.getCameraState(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('stopRecording returns null when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'stopRecording') {
              return null;
            }
            return null;
          });

      final result = await platform.stopRecording();
      expect(result, isNull);
    });

    test('setFlashMode returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setFlashMode') {
              return null;
            }
            return null;
          });

      final result = await platform.setFlashMode(DivineCameraFlashMode.on);
      expect(result, isFalse);
    });

    test('setFocusPoint returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setFocusPoint') {
              return null;
            }
            return null;
          });

      final result = await platform.setFocusPoint(const Offset(0.5, 0.5));
      expect(result, isFalse);
    });

    test('setExposurePoint returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setExposurePoint') {
              return null;
            }
            return null;
          });

      final result = await platform.setExposurePoint(const Offset(0.5, 0.5));
      expect(result, isFalse);
    });

    test('setZoomLevel returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setZoomLevel') {
              return null;
            }
            return null;
          });

      final result = await platform.setZoomLevel(2);
      expect(result, isFalse);
    });
  });

  group('MethodChannelDivineCamera native callbacks', () {
    test('handles onRecordingAutoStopped callback from native', () async {
      VideoRecordingResult? receivedResult;
      platform.onRecordingAutoStopped = (result) {
        receivedResult = result;
      };

      // Simulate native callback by invoking the method channel from "native"
      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('onRecordingAutoStopped', {
          'filePath': '/auto/stopped.mp4',
          'durationMs': 30000,
          'width': 1920,
          'height': 1080,
        }),
      );

      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'divine_camera',
              envelope,
              (data) {},
            ),
        completes,
      );

      expect(receivedResult, isNotNull);
      expect(receivedResult!.filePath, '/auto/stopped.mp4');
      expect(receivedResult!.durationMs, 30000);
    });

    test('handles onRecordingAutoStopped with null args', () async {
      platform.onRecordingAutoStopped = (result) {};

      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('onRecordingAutoStopped'),
      );

      // Should not throw
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'divine_camera',
              envelope,
              (data) {},
            ),
        completes,
      );
    });

    test('handles onRecordingAutoStopped with no callback set', () async {
      platform.onRecordingAutoStopped = null;

      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('onRecordingAutoStopped', {
          'filePath': '/test.mp4',
        }),
      );

      // Should not throw
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'divine_camera',
              envelope,
              (data) {},
            ),
        completes,
      );
    });

    test('handles unknown method call', () async {
      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('unknownMethod'),
      );

      // Should not throw, just return null
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'divine_camera',
              envelope,
              (data) {},
            ),
        completes,
      );
    });
  });
}
