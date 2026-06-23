// ABOUTME: Static guards for iOS video stabilization recorder constraints.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS stabilization recorder contract', () {
    late final String controllerSource;

    setUpAll(() {
      final controllerFile = [
        File('ios/Classes/CameraController.swift'),
        File('packages/divine_camera/ios/Classes/CameraController.swift'),
      ].firstWhere((file) => file.existsSync());

      controllerSource = controllerFile.readAsStringSync();
    });

    test('does not advertise previewOptimized for full-resolution output', () {
      expect(
        controllerSource,
        isNot(contains('candidates.append((.previewOptimized')),
      );
      expect(
        controllerSource,
        contains('previewOptimized is intentionally omitted for this recorder'),
      );
    });

    test('rejects previewOptimized requests before saving native intent', () {
      expect(
        controllerSource,
        contains('let previous = requestedStabilizationMode'),
      );
      expect(
        controllerSource,
        contains('requestedStabilizationMode = previous'),
      );
      expect(
        controllerSource,
        contains('Self.isPreviewOptimized(requestedStabilizationMode)'),
      );
    });
  });
}
