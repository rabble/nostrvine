import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/log_tag_sanitizer.dart';

void main() {
  group('sanitizeTagForLog', () {
    test('returns empty tags unchanged', () {
      expect(sanitizeTagForLog(const []), isEmpty);
    });

    test('redacts proofmode and device attestation payloads', () {
      expect(
        sanitizeTagForLog(const ['proofmode', '{"proof":"secret"}']),
        equals(const ['proofmode', '[FILTERED_FROM_LOGS]']),
      );
      expect(
        sanitizeTagForLog(const ['device_attestation', 'token-abc']),
        equals(const ['device_attestation', '[FILTERED_FROM_LOGS]']),
      );
    });

    test('leaves ordinary tags unchanged when parts are short', () {
      expect(
        sanitizeTagForLog(const ['t', 'cats', 'dogs']),
        equals(const ['t', 'cats', 'dogs']),
      );
    });

    test('truncates oversized non-sensitive tag parts', () {
      final longPart = 'x' * 181;

      expect(
        sanitizeTagForLog(['alt', longPart]),
        equals(['alt', '${'x' * 180}...(truncated)']),
      );
    });
  });

  group('sanitizeEventJsonForLog', () {
    test('sanitizes nested tags and preserves other fields', () {
      final eventMap = <String, dynamic>{
        'id': 'event-123',
        'content': 'hello',
        'tags': <dynamic>[
          <dynamic>['proofmode', '{"proof":"secret"}'],
          <dynamic>['alt', 'x' * 181],
          'non-list-tag',
        ],
      };

      expect(sanitizeEventJsonForLog(eventMap), <String, dynamic>{
        'id': 'event-123',
        'content': 'hello',
        'tags': <dynamic>[
          <String>['proofmode', '[FILTERED_FROM_LOGS]'],
          <String>['alt', '${'x' * 180}...(truncated)'],
          'non-list-tag',
        ],
      });
    });

    test('returns original map when tags field is absent or not a list', () {
      final noTags = <String, dynamic>{'id': 'event-123'};
      final wrongTags = <String, dynamic>{'tags': 'not-a-list'};

      expect(identical(sanitizeEventJsonForLog(noTags), noTags), isTrue);
      expect(identical(sanitizeEventJsonForLog(wrongTags), wrongTags), isTrue);
    });
  });
}
