import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/native_camera_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('openvine/native_camera');
  const service = MethodChannelNativeCameraPermissionService();
  final methodCalls = <MethodCall>[];

  setUp(methodCalls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps a granted native request correctly', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestPermission') {
            return true;
          }
          return null;
        });

    final result = await service.requestPermission();

    expect(result, NativeCameraPermissionStatus.granted);
    expect(methodCalls.single.method, 'requestPermission');
  });

  test('maps native permission denied into requires settings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'Camera access denied',
          );
        });

    final result = await service.requestPermission();

    expect(result, NativeCameraPermissionStatus.requiresSettings);
    expect(methodCalls.single.method, 'requestPermission');
  });

  test('opens native camera system settings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'openSystemSettings') {
            return true;
          }
          return null;
        });

    final opened = await service.openSystemSettings();

    expect(opened, isTrue);
    expect(methodCalls.single.method, 'openSystemSettings');
  });
}
