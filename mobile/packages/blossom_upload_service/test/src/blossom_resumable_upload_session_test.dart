import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(BlossomResumableUploadSession, () {
    test('copyWith replaces specified fields and preserves others', () {
      final original = BlossomResumableUploadSession(
        uploadId: 'up_1',
        uploadUrl: 'https://example.com/sessions/up_1',
        chunkSize: 1024,
        nextOffset: 0,
        expiresAt: DateTime.utc(2026),
        requiredHeaders: const {'Authorization': 'Bearer token'},
      );

      final updated = original.copyWith(
        nextOffset: 512,
        expiresAt: DateTime.utc(2026, 6),
      );

      expect(updated.uploadId, equals('up_1'));
      expect(updated.uploadUrl, equals('https://example.com/sessions/up_1'));
      expect(updated.chunkSize, equals(1024));
      expect(updated.nextOffset, equals(512));
      expect(updated.expiresAt, equals(DateTime.utc(2026, 6)));
      expect(
        updated.requiredHeaders,
        equals({'Authorization': 'Bearer token'}),
      );
    });

    test('copyWith with no arguments returns equivalent session', () {
      const original = BlossomResumableUploadSession(
        uploadId: 'up_2',
        uploadUrl: 'https://example.com/sessions/up_2',
        chunkSize: 2048,
        nextOffset: 100,
      );

      final copy = original.copyWith();

      expect(copy.uploadId, equals(original.uploadId));
      expect(copy.uploadUrl, equals(original.uploadUrl));
      expect(copy.chunkSize, equals(original.chunkSize));
      expect(copy.nextOffset, equals(original.nextOffset));
      expect(copy.expiresAt, isNull);
      expect(copy.requiredHeaders, isNull);
    });
  });
}
