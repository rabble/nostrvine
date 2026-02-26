// ABOUTME: Test suite for native macOS camera permission handling
// ABOUTME: Verifies permission requests, system settings navigation, and error handling

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/camera/native_macos_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeMacOSCamera', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Set up method channel mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'hasPermission':
                  return true;
                case 'requestPermission':
                  return true;
                case 'openSystemSettings':
                  return null;
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            null,
          );
    });

    test('should check camera permission', () async {
      final hasPermission = await NativeMacOSCamera.hasPermission();

      expect(hasPermission, isTrue);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'hasPermission');
    });

    test('should request camera permission successfully', () async {
      final granted = await NativeMacOSCamera.requestPermission();

      expect(granted, isTrue);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'requestPermission');
    });

    test('should handle permission denied and open settings', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              methodCalls.add(methodCall);

              if (methodCall.method == 'requestPermission') {
                throw PlatformException(
                  code: 'PERMISSION_DENIED',
                  message: 'Camera permission denied',
                );
              }
              if (methodCall.method == 'openSystemSettings') {
                return null;
              }
              return null;
            },
          );

      try {
        await NativeMacOSCamera.requestPermission(openSettingsOnDenied: true);
        fail('Should throw PlatformException');
      } on PlatformException catch (e) {
        expect(e.code, 'PERMISSION_DENIED');
        expect(
          methodCalls.any((call) => call.method == 'openSystemSettings'),
          isTrue,
        );
      }
    });

    test(
      'should not open settings when permission denied without flag',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('openvine/native_camera'),
              (MethodCall methodCall) async {
                methodCalls.add(methodCall);

                if (methodCall.method == 'requestPermission') {
                  throw PlatformException(
                    code: 'PERMISSION_DENIED',
                    message: 'Camera permission denied',
                  );
                }
                return null;
              },
            );

        try {
          await NativeMacOSCamera.requestPermission();
          fail('Should throw PlatformException');
        } on PlatformException catch (e) {
          expect(e.code, 'PERMISSION_DENIED');
          expect(
            methodCalls.any((call) => call.method == 'openSystemSettings'),
            isFalse,
          );
        }
      },
    );

    test('should open system settings directly', () async {
      await NativeMacOSCamera.openSystemSettings();

      expect(
        methodCalls.any((call) => call.method == 'openSystemSettings'),
        isTrue,
      );
    });

    test('should handle generic errors gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'requestPermission') {
                throw PlatformException(
                  code: 'UNKNOWN_ERROR',
                  message: 'Something went wrong',
                );
              }
              return null;
            },
          );

      final result = await NativeMacOSCamera.requestPermission();

      expect(result, isFalse);
    });

    test('should return false when permission check fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'hasPermission') {
                throw Exception('Failed to check permission');
              }
              return null;
            },
          );

      final result = await NativeMacOSCamera.hasPermission();

      expect(result, isFalse);
    });
  });
}
