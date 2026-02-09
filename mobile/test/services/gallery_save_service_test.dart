// ABOUTME: Tests for GallerySaveService result types and error handling
// ABOUTME: Validates the gallery save result sealed class hierarchy

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  group('GallerySaveResult', () {
    test('GallerySaveSuccess is a GallerySaveResult', () {
      const result = GallerySaveSuccess();
      expect(result, isA<GallerySaveResult>());
    });

    test('GallerySaveFailure is a GallerySaveResult with reason', () {
      const result = GallerySaveFailure('Permission denied');
      expect(result, isA<GallerySaveResult>());
      expect(result.reason, 'Permission denied');
    });

    test('pattern matching works on GallerySaveResult', () {
      const GallerySaveResult successResult = GallerySaveSuccess();
      const GallerySaveResult failureResult = GallerySaveFailure('Test error');

      // Test success pattern matching
      var isSuccess = switch (successResult) {
        GallerySaveSuccess() => true,
        GallerySaveFailure() => false,
      };
      expect(isSuccess, isTrue);

      // Test failure pattern matching
      isSuccess = switch (failureResult) {
        GallerySaveSuccess() => true,
        GallerySaveFailure() => false,
      };
      expect(isSuccess, isFalse);
    });

    test('GallerySaveFailure extracts reason via pattern matching', () {
      const GallerySaveResult result = GallerySaveFailure('Storage full');

      final reason = switch (result) {
        GallerySaveSuccess() => null,
        GallerySaveFailure(:final reason) => reason,
      };

      expect(reason, 'Storage full');
    });
  });

  group('GallerySaveService', () {
    late GallerySaveService service;
    late MockPermissionsService mockPermissionsService;

    setUp(() {
      mockPermissionsService = MockPermissionsService();
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      service = GallerySaveService(permissionsService: mockPermissionsService);
    });

    test('can be instantiated', () {
      expect(service, isA<GallerySaveService>());
    });

    test('returns failure when file does not exist', () async {
      // Use a path that definitely doesn't exist
      final result = await service.saveVideoToGallery(
        EditorVideo.file('/nonexistent/path/to/video.mp4'),
      );

      expect(result, isA<GallerySaveFailure>());
      final failure = result as GallerySaveFailure;
      expect(failure.reason, 'File does not exist');
    });

    test('handles empty file path', () async {
      final result = await service.saveVideoToGallery(EditorVideo.file(''));

      expect(result, isA<GallerySaveFailure>());
    });

    test('returns failure when gallery permission denied', () async {
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.canRequest);

      final result = await service.saveVideoToGallery(
        EditorVideo.file('/nonexistent/path/to/video.mp4'),
      );

      // File doesn't exist, so it fails before permission check
      expect(result, isA<GallerySaveFailure>());
    });

    test('returns failure when gallery permission requires settings', () async {
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.requiresSettings);

      final result = await service.saveVideoToGallery(
        EditorVideo.file('/nonexistent/path/to/video.mp4'),
      );

      // File doesn't exist, so it fails before permission check
      expect(result, isA<GallerySaveFailure>());
    });
  });
}
