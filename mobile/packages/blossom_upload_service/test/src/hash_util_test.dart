import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(HashUtil, () {
    group('sha256Hash', () {
      test('returns correct hex digest for known input', () {
        // SHA-256 of empty byte list
        final hash = HashUtil.sha256Hash([]);
        expect(
          hash,
          equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
        );
      });

      test('returns correct hex digest for non-empty bytes', () {
        final hash = HashUtil.sha256Hash([1, 2, 3, 4, 5]);
        expect(
          hash,
          equals(
            '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0',
          ),
        );
      });
    });

    group('sha256String', () {
      test('returns correct hex digest for known string', () {
        final hash = HashUtil.sha256String('hello');
        expect(
          hash,
          equals(
            '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
          ),
        );
      });

      test('returns correct hex digest for empty string', () {
        final hash = HashUtil.sha256String('');
        expect(
          hash,
          equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
        );
      });
    });

    group('sha256File', () {
      test('returns hash and size for file', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'hash_util_test_',
        );
        final file = File('${tempDir.path}/test.bin')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);

        final result = await HashUtil.sha256File(file);

        expect(result.size, equals(5));
        expect(
          result.hash,
          equals(
            '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0',
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('returns empty hash and zero size for empty file', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'hash_util_test_empty_',
        );
        final file = File('${tempDir.path}/empty.bin')..writeAsBytesSync([]);

        final result = await HashUtil.sha256File(file);

        expect(result.size, equals(0));
        expect(
          result.hash,
          equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
        );

        await tempDir.delete(recursive: true);
      });
    });
  });
}
